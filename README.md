# trading_system v3.0

SBI証券のkabusapiを使った自動売買（ローカル運用） + Svelte操作UI。

## Quick Start
1. 環境変数を設定
```bash
export TS_API_PASSWORD="<your_api_password>"
export TS_ORDER_PASSWORD="<your_order_password>"
export TS_SYMBOL="1579"
export TS_EXCHANGE="1"
export TS_SLEEP_INTERVAL="0.3"
export TS_FORCE_CLOSE_TIME="14:55"
export TS_MAX_DAILY_LOSS="1.0"
```

2. Backend起動
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn backend.main:app --reload --port 8000
```

3. Frontend起動
```bash
cd frontend
npm install
npm run dev
```

- UI: http://localhost:5173
- API: http://localhost:8000

## 注意
- kabusapi をローカルで起動しておく必要があります。
- 実口座での発注になります。数量は最小から試すことを推奨します。
