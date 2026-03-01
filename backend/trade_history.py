import sqlite3
import datetime as dt
import threading
from pathlib import Path
from typing import Any, Dict, List, Optional
from zoneinfo import ZoneInfo

DB_PATH = Path(__file__).resolve().parent / "trades.db"
JST = ZoneInfo("Asia/Tokyo")

_local = threading.local()


def _get_conn() -> sqlite3.Connection:
    if not hasattr(_local, "conn") or _local.conn is None:
        _local.conn = sqlite3.connect(str(DB_PATH), check_same_thread=False)
        _local.conn.row_factory = sqlite3.Row
        _local.conn.execute("PRAGMA journal_mode=WAL")
    return _local.conn


def init_db():
    conn = _get_conn()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            symbol TEXT NOT NULL,
            side TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            order_type TEXT NOT NULL,
            price REAL,
            order_id TEXT,
            status TEXT DEFAULT 'placed'
        );
        CREATE TABLE IF NOT EXISTS daily_pl (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            symbol TEXT,
            pl_total REAL,
            wallet_cash REAL,
            wallet_margin REAL,
            positions_count INTEGER DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS trades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            symbol TEXT NOT NULL,
            side TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            exec_price REAL,
            trade_type TEXT DEFAULT 'entry',
            related_trade_id INTEGER,
            realized_pl REAL,
            note TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_orders_ts ON orders(timestamp);
        CREATE INDEX IF NOT EXISTS idx_daily_pl_date ON daily_pl(date);
        CREATE INDEX IF NOT EXISTS idx_trades_ts ON trades(timestamp);
    """)
    conn.commit()


def record_order(symbol: str, side: str, quantity: int, order_type: str,
                 price: Optional[float] = None, order_id: Optional[str] = None,
                 status: str = "placed"):
    conn = _get_conn()
    now = dt.datetime.now(JST).isoformat()
    conn.execute(
        "INSERT INTO orders (timestamp, symbol, side, quantity, order_type, price, order_id, status) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (now, symbol, side, quantity, order_type, price, order_id, status),
    )
    conn.commit()


def record_pl_snapshot(symbol: Optional[str], pl_total: Optional[float],
                       wallet_cash: Optional[float], wallet_margin: Optional[float],
                       positions_count: int = 0):
    conn = _get_conn()
    now = dt.datetime.now(JST)
    conn.execute(
        "INSERT INTO daily_pl (date, timestamp, symbol, pl_total, wallet_cash, wallet_margin, positions_count) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        (now.strftime("%Y-%m-%d"), now.isoformat(), symbol, pl_total, wallet_cash, wallet_margin, positions_count),
    )
    conn.commit()


def get_orders(limit: int = 100, symbol: Optional[str] = None) -> List[Dict[str, Any]]:
    conn = _get_conn()
    if symbol:
        rows = conn.execute(
            "SELECT * FROM orders WHERE symbol = ? ORDER BY timestamp DESC LIMIT ?",
            (symbol, limit),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM orders ORDER BY timestamp DESC LIMIT ?", (limit,)
        ).fetchall()
    return [dict(r) for r in rows]


def get_daily_pl(days: int = 30) -> List[Dict[str, Any]]:
    conn = _get_conn()
    cutoff = (dt.datetime.now(JST) - dt.timedelta(days=days)).strftime("%Y-%m-%d")
    rows = conn.execute(
        "SELECT date, MAX(timestamp) as timestamp, symbol, "
        "ROUND(AVG(pl_total), 0) as pl_total, "
        "ROUND(MAX(wallet_cash), 0) as wallet_cash, "
        "ROUND(MAX(wallet_margin), 0) as wallet_margin, "
        "MAX(positions_count) as positions_count "
        "FROM daily_pl WHERE date >= ? GROUP BY date ORDER BY date",
        (cutoff,),
    ).fetchall()
    return [dict(r) for r in rows]


def get_pl_timeline(date: Optional[str] = None, limit: int = 500) -> List[Dict[str, Any]]:
    conn = _get_conn()
    if date is None:
        date = dt.datetime.now(JST).strftime("%Y-%m-%d")
    rows = conn.execute(
        "SELECT timestamp, pl_total, positions_count FROM daily_pl "
        "WHERE date = ? ORDER BY timestamp LIMIT ?",
        (date, limit),
    ).fetchall()
    return [dict(r) for r in rows]


def get_trade_stats(days: int = 30) -> Dict[str, Any]:
    conn = _get_conn()
    cutoff = (dt.datetime.now(JST) - dt.timedelta(days=days)).strftime("%Y-%m-%d")

    order_count = conn.execute(
        "SELECT COUNT(*) FROM orders WHERE timestamp >= ?", (cutoff,)
    ).fetchone()[0]

    pl_rows = conn.execute(
        "SELECT date, "
        "  (SELECT pl_total FROM daily_pl d2 WHERE d2.date = d1.date ORDER BY timestamp DESC LIMIT 1) as closing_pl "
        "FROM (SELECT DISTINCT date FROM daily_pl WHERE date >= ?) d1 ORDER BY date",
        (cutoff,),
    ).fetchall()

    daily_pls = [r["closing_pl"] for r in pl_rows if r["closing_pl"] is not None]
    win_days = sum(1 for pl in daily_pls if pl > 0)
    loss_days = sum(1 for pl in daily_pls if pl < 0)
    total_days = len(daily_pls)

    return {
        "period_days": days,
        "total_orders": order_count,
        "trading_days": total_days,
        "win_days": win_days,
        "loss_days": loss_days,
        "win_rate": round(win_days / total_days * 100, 1) if total_days > 0 else 0,
        "total_pl": round(sum(daily_pls), 0) if daily_pls else 0,
        "avg_daily_pl": round(sum(daily_pls) / total_days, 0) if total_days > 0 else 0,
        "max_daily_pl": round(max(daily_pls), 0) if daily_pls else 0,
        "min_daily_pl": round(min(daily_pls), 0) if daily_pls else 0,
    }


def import_trades_from_api(api_orders: List[Dict[str, Any]]) -> int:
    """Import executed trades from kabuS API /orders response (details=true)."""
    conn = _get_conn()
    imported = 0
    # Sort by time to process entries before exits
    sorted_orders = sorted(api_orders, key=lambda o: o.get("RecvTime", ""))
    # Track open entries per symbol for P&L pairing
    open_entries: Dict[str, Dict[str, Any]] = {}

    for order in sorted_orders:
        state = order.get("State")
        if state != 5:  # 5 = completed
            continue

        details = order.get("Details", [])
        # Find execution detail (has ExecutionID)
        exec_detail = None
        for d in details:
            if d.get("ExecutionID"):
                exec_detail = d
                break
        if not exec_detail:
            continue

        exec_price = exec_detail.get("Price")
        qty = int(exec_detail.get("Qty", 0))
        if not exec_price or qty <= 0:
            continue

        order_id = order.get("ID", "")
        symbol = order.get("Symbol", "")
        # Check if already imported (by order_id in note)
        existing = conn.execute(
            "SELECT COUNT(*) FROM trades WHERE note LIKE ?",
            (f"%{order_id}%",),
        ).fetchone()[0]
        if existing > 0:
            continue

        raw_side = str(order.get("Side", ""))
        side = "buy" if raw_side == "2" else "sell"
        timestamp = order.get("RecvTime", dt.datetime.now(JST).isoformat())

        key = symbol
        if key in open_entries and open_entries[key]["side"] != side:
            # Exit trade — pair with the open entry
            entry = open_entries[key]
            if entry["side"] == "buy":
                realized_pl = (exec_price - entry["price"]) * qty
            else:
                realized_pl = (entry["price"] - exec_price) * qty
            conn.execute(
                "INSERT INTO trades (timestamp, symbol, side, quantity, exec_price, "
                "trade_type, related_trade_id, realized_pl, note) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (timestamp, symbol, side, qty, exec_price,
                 "exit", entry["id"], realized_pl, f"imported:{order_id}"),
            )
            del open_entries[key]
        else:
            # Entry trade
            cur = conn.execute(
                "INSERT INTO trades (timestamp, symbol, side, quantity, exec_price, "
                "trade_type, note) VALUES (?, ?, ?, ?, ?, ?, ?)",
                (timestamp, symbol, side, qty, exec_price,
                 "entry", f"imported:{order_id}"),
            )
            open_entries[key] = {"side": side, "price": exec_price, "id": cur.lastrowid}
        imported += 1

    conn.commit()
    return imported


def record_trade(symbol: str, side: str, quantity: int, exec_price: Optional[float],
                 trade_type: str = "entry", related_trade_id: Optional[int] = None,
                 realized_pl: Optional[float] = None, note: Optional[str] = None) -> int:
    conn = _get_conn()
    now = dt.datetime.now(JST).isoformat()
    cur = conn.execute(
        "INSERT INTO trades (timestamp, symbol, side, quantity, exec_price, trade_type, "
        "related_trade_id, realized_pl, note) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (now, symbol, side, quantity, exec_price, trade_type, related_trade_id, realized_pl, note),
    )
    conn.commit()
    return cur.lastrowid


def get_trades(limit: int = 50, symbol: Optional[str] = None) -> List[Dict[str, Any]]:
    conn = _get_conn()
    if symbol:
        rows = conn.execute(
            "SELECT * FROM trades WHERE symbol = ? ORDER BY timestamp DESC LIMIT ?",
            (symbol, limit),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM trades ORDER BY timestamp DESC LIMIT ?", (limit,)
        ).fetchall()
    return [dict(r) for r in rows]


def get_trade_summary(days: int = 30) -> Dict[str, Any]:
    conn = _get_conn()
    cutoff = (dt.datetime.now(JST) - dt.timedelta(days=days)).strftime("%Y-%m-%d")
    rows = conn.execute(
        "SELECT * FROM trades WHERE timestamp >= ? ORDER BY timestamp",
        (cutoff,),
    ).fetchall()
    trades = [dict(r) for r in rows]

    exits = [t for t in trades if t["realized_pl"] is not None]
    total_pl = sum(t["realized_pl"] for t in exits)
    wins = [t for t in exits if t["realized_pl"] > 0]
    losses = [t for t in exits if t["realized_pl"] < 0]

    return {
        "period_days": days,
        "total_trades": len(trades),
        "entries": sum(1 for t in trades if t["trade_type"] == "entry"),
        "exits": len(exits),
        "total_realized_pl": round(total_pl, 0),
        "win_trades": len(wins),
        "loss_trades": len(losses),
        "win_rate": round(len(wins) / len(exits) * 100, 1) if exits else 0,
        "avg_win": round(sum(t["realized_pl"] for t in wins) / len(wins), 0) if wins else 0,
        "avg_loss": round(sum(t["realized_pl"] for t in losses) / len(losses), 0) if losses else 0,
        "max_win": round(max((t["realized_pl"] for t in wins), default=0), 0),
        "max_loss": round(min((t["realized_pl"] for t in losses), default=0), 0),
    }


def get_margin_daily(days: int = 30) -> List[Dict[str, Any]]:
    conn = _get_conn()
    cutoff = (dt.datetime.now(JST) - dt.timedelta(days=days)).strftime("%Y-%m-%d")
    rows = conn.execute(
        "SELECT date, "
        "ROUND(MAX(wallet_margin), 0) as wallet_margin, "
        "ROUND(MAX(wallet_cash), 0) as wallet_cash "
        "FROM daily_pl WHERE date >= ? GROUP BY date ORDER BY date",
        (cutoff,),
    ).fetchall()
    result = []
    prev_margin = None
    for r in rows:
        d = dict(r)
        margin = d.get("wallet_margin")
        d["margin_change"] = round(margin - prev_margin, 0) if margin is not None and prev_margin is not None else None
        prev_margin = margin
        result.append(d)
    return result
