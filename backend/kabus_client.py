import time
import requests
from typing import Any, Dict, List, Optional

try:
    from .config import Settings
except ImportError:
    from config import Settings

class KabuClient:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._token: Optional[str] = None
        self._token_ts: float = 0.0

    def _get_token(self) -> str:
        if self._token:
            return self._token
        url = f"{self.settings.api_base_url}/token"
        resp = requests.post(url, json={"APIPassword": self.settings.api_password})
        resp.raise_for_status()
        token = resp.json().get("Token")
        if not token:
            raise RuntimeError("failed to obtain token")
        self._token = token
        self._token_ts = time.time()
        return token

    def _request(self, method: str, path: str, params: Optional[Dict[str, Any]] = None):
        token = self._get_token()
        url = f"{self.settings.api_base_url}{path}"
        headers = {"X-API-KEY": token}
        resp = requests.request(method, url, params=params, headers=headers)
        if resp.status_code == 401:
            # refresh token once
            self._token = None
            token = self._get_token()
            headers["X-API-KEY"] = token
            resp = requests.request(method, url, params=params, headers=headers)
        resp.raise_for_status()
        return resp.json()

    def wallet_cash(self) -> Dict[str, Any]:
        return self._request("GET", "/wallet/cash")

    def wallet_margin(self) -> Dict[str, Any]:
        return self._request("GET", "/wallet/margin")

    def positions(self, symbol: Optional[str] = None) -> List[Dict[str, Any]]:
        params = {"product": "2", "addinfo": "true"}
        if symbol:
            params["symbol"] = symbol
        data = self._request("GET", "/positions", params=params)
        return data if isinstance(data, list) else []

    def orders(self, symbol: Optional[str] = None) -> List[Dict[str, Any]]:
        params = {"product": "2", "details": "false"}
        if symbol:
            params["symbol"] = symbol
        data = self._request("GET", "/orders", params=params)
        return data if isinstance(data, list) else []
