import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import sqlite3
import pytest
from unittest.mock import patch
import datetime as dt

import trade_history


@pytest.fixture(autouse=True)
def use_temp_db(tmp_path, monkeypatch):
    """Use a temporary database for each test."""
    db_path = tmp_path / "test_trades.db"
    monkeypatch.setattr(trade_history, "DB_PATH", db_path)
    # Reset thread-local connection
    if hasattr(trade_history._local, "conn"):
        trade_history._local.conn = None
    trade_history.init_db()
    yield
    if hasattr(trade_history._local, "conn") and trade_history._local.conn:
        trade_history._local.conn.close()
        trade_history._local.conn = None


class TestRecordTrade:
    def test_record_entry_trade(self):
        trade_id = trade_history.record_trade(
            symbol="8306", side="buy", quantity=100,
            exec_price=1234.5, trade_type="entry",
        )
        assert trade_id == 1
        trades = trade_history.get_trades()
        assert len(trades) == 1
        t = trades[0]
        assert t["symbol"] == "8306"
        assert t["side"] == "buy"
        assert t["quantity"] == 100
        assert t["exec_price"] == 1234.5
        assert t["trade_type"] == "entry"
        assert t["realized_pl"] is None
        assert t["related_trade_id"] is None

    def test_record_exit_trade_with_pl(self):
        entry_id = trade_history.record_trade(
            symbol="8306", side="buy", quantity=100,
            exec_price=1200.0, trade_type="entry",
        )
        exit_id = trade_history.record_trade(
            symbol="8306", side="sell", quantity=100,
            exec_price=1250.0, trade_type="exit",
            related_trade_id=entry_id,
            realized_pl=5000.0,
        )
        assert exit_id == 2
        trades = trade_history.get_trades()
        exit_trade = next(t for t in trades if t["id"] == exit_id)
        assert exit_trade["trade_type"] == "exit"
        assert exit_trade["related_trade_id"] == entry_id
        assert exit_trade["realized_pl"] == 5000.0

    def test_record_emergency_exit(self):
        trade_id = trade_history.record_trade(
            symbol="8306", side="sell", quantity=100,
            exec_price=1150.0, trade_type="emergency_exit",
            note="stop loss triggered",
        )
        trades = trade_history.get_trades()
        assert trades[0]["trade_type"] == "emergency_exit"
        assert trades[0]["note"] == "stop loss triggered"

    def test_record_force_close(self):
        trade_id = trade_history.record_trade(
            symbol="8306", side="sell", quantity=100,
            exec_price=1100.0, trade_type="force_close",
        )
        trades = trade_history.get_trades()
        assert trades[0]["trade_type"] == "force_close"

    def test_returns_autoincrement_id(self):
        id1 = trade_history.record_trade("8306", "buy", 100, 1200.0)
        id2 = trade_history.record_trade("8306", "sell", 100, 1250.0)
        assert id2 == id1 + 1


class TestGetTrades:
    def test_empty_returns_empty_list(self):
        assert trade_history.get_trades() == []

    def test_limit(self):
        for i in range(10):
            trade_history.record_trade("8306", "buy", 100, 1200.0 + i)
        trades = trade_history.get_trades(limit=3)
        assert len(trades) == 3

    def test_filter_by_symbol(self):
        trade_history.record_trade("8306", "buy", 100, 1200.0)
        trade_history.record_trade("9433", "buy", 200, 3500.0)
        trade_history.record_trade("8306", "sell", 100, 1250.0)
        trades = trade_history.get_trades(symbol="8306")
        assert len(trades) == 2
        assert all(t["symbol"] == "8306" for t in trades)

    def test_ordered_by_timestamp_desc(self):
        trade_history.record_trade("8306", "buy", 100, 1200.0)
        trade_history.record_trade("8306", "sell", 100, 1250.0)
        trades = trade_history.get_trades()
        assert trades[0]["id"] > trades[1]["id"]


class TestGetTradeSummary:
    def test_empty_summary(self):
        summary = trade_history.get_trade_summary()
        assert summary["total_trades"] == 0
        assert summary["total_realized_pl"] == 0
        assert summary["win_rate"] == 0

    def test_summary_with_wins_and_losses(self):
        # 2 winning exits, 1 losing exit
        e1 = trade_history.record_trade("8306", "buy", 100, 1200.0, "entry")
        trade_history.record_trade("8306", "sell", 100, 1250.0, "exit", e1, 5000.0)
        e2 = trade_history.record_trade("8306", "buy", 100, 1300.0, "entry")
        trade_history.record_trade("8306", "sell", 100, 1320.0, "exit", e2, 2000.0)
        e3 = trade_history.record_trade("8306", "buy", 100, 1350.0, "entry")
        trade_history.record_trade("8306", "sell", 100, 1330.0, "exit", e3, -2000.0)

        summary = trade_history.get_trade_summary()
        assert summary["total_trades"] == 6
        assert summary["entries"] == 3
        assert summary["exits"] == 3
        assert summary["total_realized_pl"] == 5000.0
        assert summary["win_trades"] == 2
        assert summary["loss_trades"] == 1
        assert summary["win_rate"] == pytest.approx(66.7, abs=0.1)
        assert summary["avg_win"] == 3500.0
        assert summary["avg_loss"] == -2000.0
        assert summary["max_win"] == 5000.0
        assert summary["max_loss"] == -2000.0

    def test_entries_only_no_exits(self):
        trade_history.record_trade("8306", "buy", 100, 1200.0, "entry")
        summary = trade_history.get_trade_summary()
        assert summary["total_trades"] == 1
        assert summary["entries"] == 1
        assert summary["exits"] == 0
        assert summary["win_rate"] == 0


class TestGetMarginDaily:
    def test_empty_returns_empty_list(self):
        assert trade_history.get_margin_daily() == []

    def test_margin_change_calculation(self):
        conn = trade_history._get_conn()
        # Insert snapshots for 2 days
        conn.execute(
            "INSERT INTO daily_pl (date, timestamp, symbol, pl_total, wallet_cash, wallet_margin, positions_count) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            ("2026-02-28", "2026-02-28T15:00:00+09:00", "8306", 0, 1000000, 3000000, 0),
        )
        conn.execute(
            "INSERT INTO daily_pl (date, timestamp, symbol, pl_total, wallet_cash, wallet_margin, positions_count) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            ("2026-03-01", "2026-03-01T15:00:00+09:00", "8306", 5000, 1005000, 3015000, 0),
        )
        conn.commit()

        result = trade_history.get_margin_daily(days=7)
        assert len(result) == 2
        # First day has no previous, so margin_change is None
        assert result[0]["margin_change"] is None
        assert result[0]["wallet_margin"] == 3000000
        # Second day shows change
        assert result[1]["margin_change"] == 15000.0
        assert result[1]["wallet_margin"] == 3015000


class TestImportTradesFromApi:
    def _make_order(self, order_id, symbol, side, price, qty, state=5):
        return {
            "ID": order_id,
            "Symbol": symbol,
            "Side": side,  # "2"=buy, "1"=sell
            "Price": 0.0,
            "CumQty": float(qty),
            "State": state,
            "RecvTime": f"2026-02-26T09:00:00+09:00",
            "Details": [
                {"SeqNum": 1, "Price": 0.0, "Qty": float(qty), "ExecutionID": None},
                {"SeqNum": 5, "Price": price, "Qty": float(qty), "ExecutionID": f"E{order_id}"},
            ],
        }

    def test_import_buy_sell_pair(self):
        orders = [
            self._make_order("ORD001", "1579", "2", 634.0, 100),  # buy
            self._make_order("ORD002", "1579", "1", 618.0, 100),  # sell
        ]
        # Ensure second order has later timestamp
        orders[1]["RecvTime"] = "2026-02-27T09:00:00+09:00"

        count = trade_history.import_trades_from_api(orders)
        assert count == 2

        trades = trade_history.get_trades()
        assert len(trades) == 2
        # Sorted by timestamp DESC, so sell (exit) first
        exit_trade = trades[0]
        entry_trade = trades[1]
        assert entry_trade["side"] == "buy"
        assert entry_trade["exec_price"] == 634.0
        assert entry_trade["trade_type"] == "entry"
        assert exit_trade["side"] == "sell"
        assert exit_trade["exec_price"] == 618.0
        assert exit_trade["trade_type"] == "exit"
        assert exit_trade["realized_pl"] == (618.0 - 634.0) * 100  # -1600

    def test_skip_non_completed_orders(self):
        orders = [
            self._make_order("ORD003", "1579", "2", 634.0, 100, state=3),  # not completed
        ]
        count = trade_history.import_trades_from_api(orders)
        assert count == 0
        assert trade_history.get_trades() == []

    def test_skip_already_imported(self):
        orders = [
            self._make_order("ORD004", "1579", "2", 634.0, 100),
        ]
        trade_history.import_trades_from_api(orders)
        # Import again — should skip
        count = trade_history.import_trades_from_api(orders)
        assert count == 0
        assert len(trade_history.get_trades()) == 1

    def test_empty_orders(self):
        assert trade_history.import_trades_from_api([]) == 0
