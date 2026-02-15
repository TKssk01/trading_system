import os
from dataclasses import dataclass
from pathlib import Path

_ENV_PATH = Path(__file__).resolve().parent / ".env"

def _load_env_file():
    if not _ENV_PATH.exists():
        return
    for line in _ENV_PATH.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value

_load_env_file()

@dataclass
class Settings:
    api_base_url: str = os.getenv("TS_API_BASE_URL", "http://localhost:18080/kabusapi")
    api_password: str = os.getenv("TS_API_PASSWORD", "")
    order_password: str = os.getenv("TS_ORDER_PASSWORD", "")
    symbol: str = os.getenv("TS_SYMBOL", "1579")
    exchange: int = int(os.getenv("TS_EXCHANGE", "1"))
    sleep_interval: float = float(os.getenv("TS_SLEEP_INTERVAL", "0.3"))
    force_close_time: str = os.getenv("TS_FORCE_CLOSE_TIME", "14:55")
    max_daily_loss: float = float(os.getenv("TS_MAX_DAILY_LOSS", "1.0"))

settings = Settings()
