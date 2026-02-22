"""
Professional プラン維持スクリプト

kabuステーションAPIを使って月1回最小単元の取引を行い、
Professionalプランを維持する。

使い方:
  cd C:\trading_system
  .venv\Scripts\python.exe scripts\keep_professional.py

環境変数または backend/.env から設定を読み込む。
"""

import os
import sys
import json
import time
import requests
from pathlib import Path
from datetime import datetime

# --- 設定 ---
API_BASE_URL = os.getenv("TS_API_BASE_URL", "http://localhost:18080/kabusapi")
API_PASSWORD = os.getenv("TS_API_PASSWORD", "")
ORDER_PASSWORD = os.getenv("TS_ORDER_PASSWORD", "")

# 安い銘柄リスト (ETF/低位株、100株単元)
# 1株あたり数百円程度の銘柄を優先
CHEAP_SYMBOLS = [
    {"symbol": "1689", "exchange": 1, "name": "ガスETF"},
    {"symbol": "1546", "exchange": 1, "name": "ダウETF"},
    {"symbol": "2842", "exchange": 1, "name": "NF NASDAQ100ヘッジ無"},
]

def load_env():
    """backend/.env から設定を読み込む"""
    global API_PASSWORD, ORDER_PASSWORD
    env_path = Path(__file__).resolve().parent.parent / "backend" / ".env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8-sig").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key == "TS_API_PASSWORD" and not API_PASSWORD:
                API_PASSWORD = value
            elif key == "TS_ORDER_PASSWORD" and not ORDER_PASSWORD:
                ORDER_PASSWORD = value

def get_token():
    """APIトークンを取得"""
    url = f"{API_BASE_URL}/token"
    resp = requests.post(url, json={"APIPassword": API_PASSWORD})
    resp.raise_for_status()
    token = resp.json().get("Token")
    if not token:
        raise RuntimeError("トークン取得失敗")
    return token

def get_board(token, symbol, exchange):
    """銘柄の板情報を取得"""
    url = f"{API_BASE_URL}/board/{symbol}@{exchange}"
    headers = {"X-API-KEY": token}
    resp = requests.get(url, headers=headers)
    resp.raise_for_status()
    return resp.json()

def send_order(token, symbol, exchange, side, qty, price, order_password):
    """
    注文を送信
    side: "2" = 買い, "1" = 売り
    """
    url = f"{API_BASE_URL}/sendorder"
    headers = {"X-API-KEY": token}
    body = {
        "Password": order_password,
        "Symbol": symbol,
        "Exchange": exchange,
        "SecurityType": 1,        # 株式
        "Side": side,
        "CashMargin": 1,          # 現物
        "DelivType": 2,           # お預り金
        "FundType": "AA",
        "AccountType": 4,         # 特定
        "Qty": qty,
        "FrontOrderType": 20,     # 指値
        "Price": price,
        "ExpireDay": 0,           # 当日
    }
    resp = requests.post(url, json=body, headers=headers)
    resp.raise_for_status()
    result = resp.json()
    if result.get("Result") != 0:
        raise RuntimeError(f"注文失敗: {result}")
    return result

def get_orders(token):
    """当日の注文一覧を取得"""
    url = f"{API_BASE_URL}/orders"
    headers = {"X-API-KEY": token}
    params = {"product": "0"}
    resp = requests.get(url, headers=headers, params=params)
    resp.raise_for_status()
    return resp.json()

def cancel_order(token, order_id, order_password):
    """注文を取り消す"""
    url = f"{API_BASE_URL}/cancelorder"
    headers = {"X-API-KEY": token}
    body = {"OrderId": order_id, "Password": order_password}
    resp = requests.put(url, json=body, headers=headers)
    resp.raise_for_status()
    return resp.json()

def main():
    load_env()

    if not API_PASSWORD or not ORDER_PASSWORD:
        print("[ERROR] API_PASSWORD または ORDER_PASSWORD が未設定です")
        print("        backend/.env または環境変数で設定してください")
        sys.exit(1)

    print(f"[{datetime.now()}] Professional維持トレード開始")
    print(f"  API: {API_BASE_URL}")

    # トークン取得
    token = get_token()
    print("  トークン取得OK")

    # 安い銘柄の現在値を確認して一番安いものを選ぶ
    best = None
    for candidate in CHEAP_SYMBOLS:
        try:
            board = get_board(token, candidate["symbol"], candidate["exchange"])
            price = board.get("CurrentPrice")
            if price and price > 0:
                cost = price * 100  # 100株単元
                print(f"  {candidate['name']}({candidate['symbol']}): {price}円 x 100株 = {cost:,.0f}円")
                if best is None or cost < best["cost"]:
                    best = {
                        "symbol": candidate["symbol"],
                        "exchange": candidate["exchange"],
                        "name": candidate["name"],
                        "price": price,
                        "cost": cost,
                    }
        except Exception as e:
            print(f"  {candidate['name']}({candidate['symbol']}): 取得失敗 - {e}")

    if not best:
        print("[ERROR] 取引可能な銘柄が見つかりません")
        sys.exit(1)

    print(f"\n  選択: {best['name']}({best['symbol']}) {best['price']}円")
    print(f"  必要資金: 約 {best['cost']:,.0f}円")

    # 成行に近い指値で買い注文 (現在値で指値)
    print("\n  買い注文送信中...")
    buy_result = send_order(
        token=token,
        symbol=best["symbol"],
        exchange=best["exchange"],
        side="2",  # 買い
        qty=100,
        price=best["price"],
        order_password=ORDER_PASSWORD,
    )
    order_id = buy_result.get("OrderId")
    print(f"  買い注文送信OK: OrderId={order_id}")

    # 約定を待つ (最大60秒)
    print("  約定待ち...")
    executed = False
    for i in range(12):
        time.sleep(5)
        orders = get_orders(token)
        for order in orders:
            if order.get("OrderId") == order_id:
                state = order.get("State")
                # State: 1=待機, 2=処理中, 3=処理済, 4=訂正取消送信中, 5=終了
                if state == 5:
                    cum_qty = order.get("CumQty", 0)
                    if cum_qty > 0:
                        print(f"  約定完了! 数量: {cum_qty}")
                        executed = True
                    else:
                        print(f"  注文終了（未約定）")
                    break
        if executed:
            break
        print(f"  待機中... ({(i+1)*5}秒)")

    if not executed:
        # 約定しなかった場合は注文取消
        print("  約定しませんでした。注文を取り消します...")
        try:
            cancel_order(token, order_id, ORDER_PASSWORD)
            print("  注文取消OK")
        except Exception as e:
            print(f"  注文取消失敗: {e}")
        print("\n[INFO] 価格が動いている可能性があります。手動で取引してください。")
        sys.exit(1)

    print(f"\n[OK] Professional維持トレード完了")
    print(f"     {best['name']}({best['symbol']}) を{best['price']}円で100株購入")
    print(f"     ※不要であれば後で売却してください")

if __name__ == "__main__":
    main()
