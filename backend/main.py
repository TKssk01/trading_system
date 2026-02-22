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

runner = TradingRunner(settings, logger)
client = KabuClient(settings)

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

@app.get("/api/account")
def account():
    symbol = runner.get_state().get("symbol")
    try:
        wallet_cash = client.wallet_cash()
        wallet_margin = client.wallet_margin()
        all_positions = client.positions(symbol=None)
        symbol_positions = [p for p in all_positions if str(p.get('Symbol', '')) == str(symbol)] if symbol else all_positions
        orders = client.orders(symbol=symbol)
        pl_total = 0.0
        for p in all_positions:
            pl = p.get('ProfitLoss')
            try:
                pl_total += float(pl)
            except Exception:
                pass
        return {
            "wallet_cash": wallet_cash,
            "wallet_margin": wallet_margin,
            "positions": symbol_positions,
            "all_positions": all_positions,
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
