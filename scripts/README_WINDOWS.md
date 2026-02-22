# trading_system v3.0 - Windows セットアップガイド

## 概要

VMware Fusion上のWindows環境でtrading_system v3.0を動かすための手順書です。

SBI証券のkabusapi（kabuステーション）を利用した自動売買システムのバックエンド（Python/FastAPI）とフロントエンド（Svelte）をWindows上で構築・運用します。

## 前提条件

- VMware Fusion上のWindows 11
- インターネット接続
- SBI証券のkabuステーション（kabusapi）がWindows上にインストール・起動済みであること

## セットアップ手順

### 1. プロジェクトをWindowsにコピー

#### 方法A: VMware Fusionの共有フォルダ機能を使用（推奨）

**Mac側の設定:**

1. VMware Fusionを開く
2. 仮想マシンの設定 → 共有フォルダ → 共有フォルダを有効にする
3. プロジェクトディレクトリ（`trading_system`）を共有フォルダとして追加

**Windows側の操作:**

1. エクスプローラーを開く
2. アドレスバーに `\\vmware-host\Shared Folders\` と入力してアクセス
3. `trading_system` フォルダを `C:\trading_system` にコピー

```powershell
Copy-Item "\\vmware-host\Shared Folders\trading_system" -Destination "C:\trading_system" -Recurse
```

#### 方法B: その他の方法

- USBメモリ経由でコピー
- ネットワーク共有（SMB）経由でコピー

> **注意:** 共有フォルダ上で直接実行するのではなく、必ずローカルドライブ（`C:\`）にコピーしてから作業してください。パフォーマンスとパーミッションの問題を回避できます。

### 2. 環境構築

PowerShellを **管理者として** 実行し、以下のコマンドでセットアップスクリプトを実行します。

```powershell
cd C:\trading_system
.\scripts\setup_windows.ps1
```

このスクリプトは以下をインストール・設定します:

- Python 3
- Node.js / npm
- Pythonの仮想環境（`.venv`）の作成
- pip依存パッケージのインストール（`backend/requirements.txt`）
- npm依存パッケージのインストール（`frontend/package.json`）

> **注意:** 初回実行時、PythonやNode.jsのインストール後にPATHが反映されない場合があります。その場合はPowerShellを一度閉じて再度開いてから、スクリプトを再実行してください。

### 3. 環境変数の設定

以下のスクリプトを実行して、APIパスワード等の環境変数を設定します。

```powershell
.\scripts\create_env.ps1
```

対話形式で以下の値を入力します:

| 環境変数 | 説明 | 例 |
|---|---|---|
| `TS_API_PASSWORD` | kabusapi のAPIパスワード | （SBI証券で設定したもの） |
| `TS_ORDER_PASSWORD` | 注文用パスワード | （SBI証券で設定したもの） |
| `TS_SYMBOL` | 取引対象の銘柄コード | `1579` |
| `TS_EXCHANGE` | 取引所コード | `1` |
| `TS_SLEEP_INTERVAL` | API呼び出し間隔（秒） | `0.3` |
| `TS_FORCE_CLOSE_TIME` | 強制決済時刻 | `14:55` |
| `TS_MAX_DAILY_LOSS` | 1日の最大損失許容額（%） | `1.0` |

### 4. 起動方法

全サービス（バックエンド + フロントエンド）を一括で起動します。

```powershell
.\scripts\start_all.ps1
```

起動後、ブラウザで以下のURLにアクセスしてください:

- **UI（フロントエンド）:** http://localhost:5173
- **API（バックエンド）:** http://localhost:8000

> **前提:** kabuステーションがWindows上で起動し、kabusapiが有効になっている必要があります。

### 5. 停止方法

全サービスを停止するには、以下を実行します。

```powershell
.\scripts\stop_all.ps1
```

## トラブルシューティング

### wingetが見つからない場合

`winget` コマンドが認識されない場合は、Microsoft Storeから「アプリ インストーラー」を最新版に更新してください。

1. Microsoft Storeを開く
2. 「アプリ インストーラー」を検索
3. 更新（またはインストール）する

### PowerShellスクリプトが実行できない場合

実行ポリシーにより `.ps1` ファイルの実行がブロックされている場合があります。管理者権限のPowerShellで以下を実行してください。

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### kabusapiに接続できない場合

1. kabuステーションがWindows上で起動しているか確認してください
2. kabuステーションにログイン済みであることを確認してください
3. kabusapiが有効になっていることを確認してください（kabuステーションの設定画面）
4. APIパスワードが正しく設定されているか確認してください

### PATHが通らない場合

PythonやNode.jsのインストール直後はPATHが反映されないことがあります。

1. PowerShellを閉じる
2. PowerShellを再度管理者として開く
3. `python --version` および `node --version` で確認する

### ポートが既に使用されている場合

バックエンド（8000番）やフロントエンド（5173番）のポートが他のアプリケーションに使われている場合は、該当プロセスを終了してください。

```powershell
# ポート8000を使用しているプロセスを確認
netstat -ano | findstr :8000

# プロセスIDを指定して終了
taskkill /PID <プロセスID> /F
```

## 注意事項

- kabusapiはローカルで起動しておく必要があります。
- **実口座での発注になります。** 数量は最小から試すことを強く推奨します。
- 環境変数にはパスワード等の機密情報が含まれます。第三者に共有しないでください。
