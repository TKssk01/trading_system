import logging
import threading
import datetime as dt
from pathlib import Path
from typing import Optional
from zoneinfo import ZoneInfo

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

try:
    from .config import settings
    from .log_buffer import MemoryLogHandler
    from .runner import TradingRunner
    from .kabus_client import KabuClient
    from .trade_history import init_db, record_pl_snapshot, get_orders as get_trade_orders, get_daily_pl, get_pl_timeline, get_trade_stats
except ImportError:
    from config import settings
    from log_buffer import MemoryLogHandler
    from runner import TradingRunner
    from kabus_client import KabuClient
    from trade_history import init_db, record_pl_snapshot, get_orders as get_trade_orders, get_daily_pl, get_pl_timeline, get_trade_stats

LOG_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"

logger = logging.getLogger("TradingLogger")
logger.setLevel(logging.INFO)
logger.propagate = False

mem_handler = MemoryLogHandler(capacity=1000)
mem_handler.setFormatter(logging.Formatter(LOG_FORMAT))
logger.addHandler(mem_handler)

app = FastAPI(title="trading_system v3.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

client = KabuClient(settings)
runner = TradingRunner(settings, logger, kabu_client=client)

# Initialize trade history DB
init_db()

# Periodic P&L snapshot recorder
def _pl_snapshot_loop():
    import time as _time
    while True:
        _time.sleep(30)  # every 30 seconds
        try:
            state = runner.get_state()
            if not state.get("running"):
                continue
            symbol = state.get("symbol")
            positions = client.positions(symbol=symbol)
            pl_total = sum(float(p.get("ProfitLoss", 0)) for p in positions)
            try:
                wc = client.wallet_cash()
                cash = wc.get("StockAccountWallet")
            except Exception:
                cash = None
            try:
                wm = client.wallet_margin()
                margin = wm.get("MarginAccountWallet")
            except Exception:
                margin = None
            record_pl_snapshot(symbol, pl_total, cash, margin, len(positions))
        except Exception:
            pass

_pl_thread = threading.Thread(target=_pl_snapshot_loop, name="pl-snapshot", daemon=True)
_pl_thread.start()

class ConfigUpdate(BaseModel):
    symbol: Optional[str] = None
    quantity: Optional[int] = None

class SecretsUpdate(BaseModel):
    api_password: Optional[str] = None
    order_password: Optional[str] = None
    save: bool = False

class ScheduleStart(BaseModel):
    time: str  # "HH:MM" format in JST

# Scheduled start state
_scheduled_time: Optional[str] = None
_schedule_timer: Optional[threading.Timer] = None
_schedule_lock = threading.Lock()

@app.get("/api/health")
def health():
    return {"ok": True}

@app.get("/api/status")
def status():
    state = runner.get_state()
    state["positions"] = runner.get_positions()
    return state

@app.get("/api/logs")
def logs(limit: int = 200):
    return {"logs": mem_handler.get_logs(limit=limit)}

@app.post("/api/start")
def start():
    return runner.start()

@app.post("/api/stop")
def stop():
    return runner.stop()

@app.post("/api/force_close")
def force_close():
    return runner.force_close()

@app.post("/api/schedule_start")
def schedule_start(payload: ScheduleStart):
    global _scheduled_time, _schedule_timer
    with _schedule_lock:
        # Cancel existing schedule
        if _schedule_timer:
            _schedule_timer.cancel()
            _schedule_timer = None
            _scheduled_time = None

        try:
            hh, mm = payload.time.split(":")
            now = dt.datetime.now(ZoneInfo("Asia/Tokyo"))
            target = now.replace(hour=int(hh), minute=int(mm), second=0, microsecond=0)
            if target <= now:
                target += dt.timedelta(days=1)
            delay = (target - now).total_seconds()
            _scheduled_time = payload.time

            def _do_start():
                global _scheduled_time
                logger.info("Scheduled start triggered at %s", payload.time)
                runner.start()
                _scheduled_time = None

            _schedule_timer = threading.Timer(delay, _do_start)
            _schedule_timer.daemon = True
            _schedule_timer.start()
            logger.info("Scheduled start at %s (%.0f seconds from now)", payload.time, delay)
            return {"ok": True, "scheduled_time": payload.time, "delay_seconds": int(delay)}
        except Exception as e:
            return {"ok": False, "message": str(e)}

@app.post("/api/cancel_schedule")
def cancel_schedule():
    global _scheduled_time, _schedule_timer
    with _schedule_lock:
        if _schedule_timer:
            _schedule_timer.cancel()
            _schedule_timer = None
            _scheduled_time = None
            return {"ok": True, "message": "Schedule cancelled"}
        return {"ok": False, "message": "No schedule active"}

@app.get("/api/schedule")
def get_schedule():
    return {"scheduled_time": _scheduled_time}

@app.post("/api/config")
def update_config(payload: ConfigUpdate):
    runner.update_config(symbol=payload.symbol, quantity=payload.quantity)
    return {"ok": True}

@app.post("/api/secrets")
def update_secrets(payload: SecretsUpdate):
    updated = {}
    if payload.api_password is not None:
        settings.api_password = payload.api_password
        updated['api_password'] = True
    if payload.order_password is not None:
        settings.order_password = payload.order_password
        updated['order_password'] = True
    # reset token in client
    try:
        client._token = None
    except Exception:
        pass
    if payload.save:
        # write to backend/.env
        from pathlib import Path
        env_path = Path(__file__).resolve().parent / '.env'
        lines = []
        existing = {}
        if env_path.exists():
            for line in env_path.read_text().splitlines():
                if '=' in line and not line.strip().startswith('#'):
                    k, v = line.split('=', 1)
                    existing[k.strip()] = v.strip()
        if payload.api_password is not None:
            existing['TS_API_PASSWORD'] = payload.api_password
        if payload.order_password is not None:
            existing['TS_ORDER_PASSWORD'] = payload.order_password
        for k, v in existing.items():
            lines.append(f"{k}={v}")
        env_path.write_text("\n".join(lines) + "\n")
        try:
            import os
            os.chmod(env_path, 0o600)
        except Exception:
            pass
    return {"ok": True, "updated": updated, "saved": payload.save}

@app.get("/api/indices")
def indices():
    codes = [("101", "日経平均"), ("151", "TOPIX")]
    results = []
    for code, name in codes:
        try:
            data = client.board(code)
            results.append({
                "code": code,
                "name": name,
                "price": data.get("CurrentPrice"),
                "change": data.get("ChangePreviousClose"),
                "change_pct": data.get("ChangePreviousClosePer"),
            })
        except Exception:
            results.append({"code": code, "name": name, "price": None, "change": None, "change_pct": None})
    # USD/JPY
    try:
        fx = client.exchange_rate("USD/JPY")
        results.append({
            "code": "FX",
            "name": "USD/JPY",
            "price": fx.get("BidPrice"),
            "change": fx.get("Change"),
            "change_pct": None,
        })
    except Exception:
        results.append({"code": "FX", "name": "USD/JPY", "price": None, "change": None, "change_pct": None})
    return results

WATCHLIST_CODES = [
    ("8306", "三菱UFJ"), ("9433", "KDDI"), ("8058", "三菱商"),
    ("8604", "野村"), ("9501", "東電HD"), ("7261", "マツダ"),
    ("5401", "日本製鉄"), ("9104", "商船三井"), ("6501", "日立"),
    ("9101", "郵船"), ("7012", "川重"), ("7011", "三菱重"),
    ("6702", "富士通"), ("7201", "日産自"),
]

@app.get("/api/watchlist")
def watchlist():
    results = []
    for code, name in WATCHLIST_CODES:
        try:
            data = client.board(code)
            results.append({
                "code": code,
                "name": name,
                "price": data.get("CurrentPrice"),
                "change": data.get("ChangePreviousClose"),
                "change_pct": data.get("ChangePreviousClosePer"),
                "volume": data.get("TradingVolume"),
                "previous_close": data.get("PreviousClose"),
            })
        except Exception:
            results.append({"code": code, "name": name, "price": None, "change": None, "change_pct": None, "volume": None, "previous_close": None})
    return results

@app.get("/api/symbol/{code}")
def symbol_info(code: str):
    try:
        data = client.symbol_info(code)
        return {
            "symbol": data.get("Symbol"),
            "symbol_name": data.get("SymbolName"),
            "display_name": data.get("DisplayName"),
            "exchange": data.get("ExchangeName"),
        }
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/board/{code}")
def board(code: str):
    try:
        data = client.board(code)
        return {
            "current_price": data.get("CurrentPrice"),
            "current_price_time": data.get("CurrentPriceTime"),
            "previous_close": data.get("PreviousClose"),
            "change": data.get("ChangePreviousClose"),
            "change_pct": data.get("ChangePreviousClosePer"),
            "opening_price": data.get("OpeningPrice"),
            "high_price": data.get("HighPrice"),
            "low_price": data.get("LowPrice"),
            "trading_volume": data.get("TradingVolume"),
            "vwap": data.get("VWAP"),
            "bid_price": data.get("BidPrice"),
            "bid_qty": data.get("BidQty"),
            "ask_price": data.get("AskPrice"),
            "ask_qty": data.get("AskQty"),
        }
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/account")
def account():
    symbol = runner.get_state().get("symbol")
    try:
        wallet_cash = client.wallet_cash()
        wallet_margin = client.wallet_margin()
        positions = client.positions(symbol=symbol)
        orders = client.orders(symbol=symbol)
        pl_total = 0.0
        for p in positions:
            pl = p.get('ProfitLoss')
            try:
                pl_total += float(pl)
            except Exception:
                pass
        return {
            "wallet_cash": wallet_cash,
            "wallet_margin": wallet_margin,
            "positions": positions,
            "orders": orders,
            "positions_pl_total": pl_total,
        }
    except Exception as e:
        return {"error": str(e)}

# Trade history endpoints
@app.get("/api/trade-history/orders")
def trade_history_orders(limit: int = 100, symbol: Optional[str] = None):
    return get_trade_orders(limit=limit, symbol=symbol)

@app.get("/api/trade-history/daily")
def trade_history_daily(days: int = 30):
    return get_daily_pl(days=days)

@app.get("/api/trade-history/timeline")
def trade_history_timeline(date: Optional[str] = None):
    return get_pl_timeline(date=date)

@app.get("/api/trade-history/stats")
def trade_history_stats(days: int = 30):
    return get_trade_stats(days=days)

# Serve built frontend if available
frontend_dist = Path(__file__).resolve().parent.parent / "frontend" / "dist"
if frontend_dist.exists():
    app.mount("/", StaticFiles(directory=str(frontend_dist), html=True), name="frontend")

    @app.get("/")
    def index():
        return FileResponse(frontend_dist / "index.html")
