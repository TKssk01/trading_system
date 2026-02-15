import datetime as dt
import threading
import time
import logging
import sys
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Optional, Dict, Any

from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from initializations import Initializations
from trading_data import TradingData
from order_executor import OrderExecutor, get_token
from post_order_processor import PostOrderProcessor

try:
    from .config import Settings
except ImportError:
    from config import Settings

@dataclass
class RunnerState:
    running: bool = False
    symbol: str = ""
    quantity: int = 0
    last_price: Optional[float] = None
    last_signal: Optional[Dict[str, Any]] = None
    last_error: Optional[str] = None
    last_update: Optional[str] = None
    mode: str = "daytrade"

class TradingRunner:
    def __init__(self, settings: Settings, logger: logging.Logger):
        self.settings = settings
        self.logger = logger
        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._state = RunnerState(
            symbol=settings.symbol,
            quantity=100,
            mode="daytrade",
        )
        self._init: Optional[Initializations] = None
        self._trading_data: Optional[TradingData] = None
        self._order_executor: Optional[OrderExecutor] = None
        self._post_processor: Optional[PostOrderProcessor] = None

    def get_state(self) -> Dict[str, Any]:
        with self._lock:
            return asdict(self._state)

    def update_config(self, symbol: Optional[str] = None, quantity: Optional[int] = None):
        with self._lock:
            if symbol:
                self._state.symbol = symbol
            if quantity is not None and quantity > 0:
                self._state.quantity = int(quantity)

    def start(self) -> Dict[str, Any]:
        with self._lock:
            if self._state.running:
                return {"ok": False, "message": "already running"}
            if not self.settings.api_password or not self.settings.order_password:
                return {"ok": False, "message": "API password(s) not configured"}
            self._stop_event.clear()
            self._state.running = True
            self._state.last_error = None
            self._thread = threading.Thread(target=self._run, name="trading-runner", daemon=True)
            self._thread.start()
            return {"ok": True}

    def stop(self) -> Dict[str, Any]:
        self._stop_event.set()
        with self._lock:
            self._state.running = False
        return {"ok": True}

    def force_close(self) -> Dict[str, Any]:
        try:
            closed = self._force_close_positions()
            return {"ok": True, "closed": closed}
        except Exception as e:
            self.logger.exception("force_close failed")
            return {"ok": False, "error": str(e)}

    def get_positions(self):
        if not self._order_executor:
            return []
        try:
            return self._order_executor.get_positions() or []
        except Exception:
            self.logger.exception('get_positions failed')
            return []

    def _run(self) -> None:
        try:
            self._init = Initializations()
            self._init.api_base_url = self.settings.api_base_url
            self._init.order_password = self.settings.order_password

            with self._lock:
                self._init.symbol = self._state.symbol
                self._init.exchange = self.settings.exchange
                self._init.default_quantity = self._state.quantity

            self._init.logger = self.logger

            token = get_token(self.settings.api_password)
            if not token:
                raise RuntimeError("failed to get API token")
            self._init.token = token

            self._trading_data = TradingData(self._init, token)
            self._order_executor = OrderExecutor(self._init, self._trading_data, token, self.settings.order_password)
            self._post_processor = PostOrderProcessor(self._init)

            initial_price = self._trading_data.fetch_current_price()
            self._init.previous_price = initial_price
            self._init.current_price = initial_price
            self.logger.info("initial price set: %s", initial_price)

            while not self._stop_event.is_set():
                now = dt.datetime.now(ZoneInfo("Asia/Tokyo"))
                if self._should_force_close(now):
                    self.logger.warning("force close time reached: %s", now.strftime("%H:%M"))
                    self._force_close_positions()
                    break

                current_price = self._trading_data.fetch_current_price()
                with self._lock:
                    self._state.last_price = current_price
                    self._state.last_update = now.isoformat()

                if current_price is not None:
                    if len(self._init.prices) >= 4:
                        self._trading_data.create_ohlc()
                        self._trading_data.calculate_buy_and_hold_equity()
                        self._trading_data.calculate_technical_indicators()
                        band_width = self._init.df['band_width']
                        hist = self._init.df['hist']
                        di_difference = self._init.df['di_difference']
                        adx_difference = self._init.df['adx_difference']
                        self._trading_data.update_latest_9_data(band_width, hist, di_difference, adx_difference)
                        self._post_processor.calculate_trading_values(dt.datetime.now())
                        self._trading_data.generate_signals(
                            self._init.interpolated_data,
                            self._init.R1,
                            self._init.R2,
                            self._init.R3,
                            self._init.S1,
                            self._init.S2,
                            self._init.S3,
                        )
                        self._capture_last_signal()
                        self._order_executor.execute_orders()

                if self._max_loss_hit():
                    self.logger.error("max daily loss hit; stopping")
                    self._force_close_positions()
                    break

                time.sleep(self.settings.sleep_interval)

        except Exception as e:
            self.logger.exception("runner failed")
            with self._lock:
                self._state.last_error = str(e)
        finally:
            with self._lock:
                self._state.running = False

    def _capture_last_signal(self) -> None:
        try:
            if self._init is None or self._init.interpolated_data.empty:
                return
            last_row = self._init.interpolated_data.iloc[-1]
            signals = {
                "buy": int(last_row.get('buy_signals', 0) or 0),
                "sell": int(last_row.get('sell_signals', 0) or 0),
                "buy_exit": int(last_row.get('buy_exit_signals', 0) or 0),
                "sell_exit": int(last_row.get('sell_exit_signals', 0) or 0),
                "emergency_buy_exit": int(last_row.get('emergency_buy_exit_signals', 0) or 0),
                "emergency_sell_exit": int(last_row.get('emergency_sell_exit_signals', 0) or 0),
            }
            with self._lock:
                self._state.last_signal = signals
        except Exception:
            self.logger.exception("failed to capture last signal")

    def _should_force_close(self, now: dt.datetime) -> bool:
        try:
            hh, mm = self.settings.force_close_time.split(":")
            cutoff = now.replace(hour=int(hh), minute=int(mm), second=0, microsecond=0)
            return now >= cutoff
        except Exception:
            return False

    def _max_loss_hit(self) -> bool:
        if self._init is None:
            return False
        if self.settings.max_daily_loss <= 0:
            return False
        equity = float(self._init.cash + self._init.stock_value)
        threshold = float(self._init.first_balance) * (1.0 - (self.settings.max_daily_loss / 100.0))
        return equity <= threshold

    def _force_close_positions(self) -> int:
        if not self._order_executor or not self._trading_data:
            return 0
        positions = self._order_executor.get_positions() or []
        if not positions:
            return 0
        current_price = self._trading_data.fetch_current_price() or self._state.last_price
        closed = 0
        for pos in positions:
            hold_id = pos.get("HoldID") or pos.get("HoldId") or pos.get("Holdid")
            side = str(pos.get("Side"))
            qty = int(pos.get("LeavesQty") or pos.get("Qty") or 0)
            if not hold_id or qty <= 0:
                continue
            close_side = "1" if side == "2" else "2"
            try:
                self._order_executor.exit_ioc_order(close_side, qty, hold_id, current_price)
                closed += 1
            except Exception:
                self.logger.exception("failed to close position")
        return closed
