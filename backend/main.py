import logging
from pathlib import Path
from typing import Optional

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
except ImportError:
    from config import settings
    from log_buffer import MemoryLogHandler
    from runner import TradingRunner
    from kabus_client import KabuClient

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

class ConfigUpdate(BaseModel):
    symbol: Optional[str] = None
    quantity: Optional[int] = None

class SecretsUpdate(BaseModel):
    api_password: Optional[str] = None
    order_password: Optional[str] = None
    save: bool = False

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

# Serve built frontend if available
frontend_dist = Path(__file__).resolve().parent.parent / "frontend" / "dist"
if frontend_dist.exists():
    app.mount("/", StaticFiles(directory=str(frontend_dist), html=True), name="frontend")

    @app.get("/")
    def index():
        return FileResponse(frontend_dist / "index.html")
