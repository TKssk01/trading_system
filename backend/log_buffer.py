import logging
import threading
from collections import deque

class MemoryLogHandler(logging.Handler):
    def __init__(self, capacity: int = 500):
        super().__init__()
        self.capacity = capacity
        self._lock = threading.Lock()
        self._records = deque(maxlen=capacity)

    def emit(self, record: logging.LogRecord) -> None:
        msg = self.format(record)
        with self._lock:
            self._records.append(msg)

    def get_logs(self, limit: int = 200):
        with self._lock:
            if limit <= 0:
                return []
            return list(self._records)[-limit:]
