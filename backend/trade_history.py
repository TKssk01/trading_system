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
        CREATE INDEX IF NOT EXISTS idx_orders_ts ON orders(timestamp);
        CREATE INDEX IF NOT EXISTS idx_daily_pl_date ON daily_pl(date);
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
