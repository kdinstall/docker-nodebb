# Express Sample Application

Node.js v24 + Express を使用したシンプルなサンプルアプリケーションです。

## 概要

このアプリケーションは、Docker環境で実行される Express ベースの REST API サーバーです。基本的なエンドポイントを提供します。

## 技術スタック

- **Node.js**: v24 (Alpine)
- **パッケージマネージャー**: pnpm
- **フレームワーク**: Express
- **モジュール形式**: ESM (ES Modules)
- **ポート**: 3000

## API エンドポイント

### `GET /`
アプリケーション情報と利用可能なエンドポイント一覧を返します。

**レスポンス例:**
```json
{
  "message": "Express Sample Application",
  "version": "1.0.0",
  "endpoints": {
    "health": "/health",
    "hello": "/hello/:name",
    "echo": "POST /echo"
  }
}
```

### `GET /health`
アプリケーションのヘルスチェック。

**レスポンス例:**
```json
{
  "status": "healthy",
  "timestamp": "2026-02-01T12:00:00.000Z",
  "uptime": 123.456
}
```

### `GET /hello/:name`
指定された名前で挨拶メッセージを返します。名前は省略可能（省略時は "World"）。

**リクエスト例:**
```bash
curl http://192.168.33.10/hello/Alice
```

**レスポンス例:**
```json
{
  "message": "Hello, Alice!",
  "timestamp": "2026-02-01T12:00:00.000Z"
}
```

### `POST /echo`
送信されたJSONデータをそのまま返します（エコーバック）。

**リクエスト例:**
```bash
curl -X POST http://192.168.33.10/echo \
  -H "Content-Type: application/json" \
  -d '{"name":"test","value":123}'
```

**レスポンス例:**
```json
{
  "received": {
    "name": "test",
    "value": 123
  },
  "timestamp": "2026-02-01T12:00:00.000Z"
}
```

## 動作確認

Vagrant環境を起動後、以下のコマンドで各エンドポイントをテストできます：

```bash
# アプリケーション情報
curl http://192.168.33.10/

# ヘルスチェック
curl http://192.168.33.10/health

# Hello エンドポイント
curl http://192.168.33.10/hello
curl http://192.168.33.10/hello/Alice

# Echo エンドポイント
curl -X POST http://192.168.33.10/echo \
  -H "Content-Type: application/json" \
  -d '{"test":"data"}'
```

HTTPSでテストする場合（本番環境）:
```bash
curl https://example.com/health
curl https://example.com/hello/World
```

## 起動方法

### 開発環境（Vagrant）

1. Vagrant 環境を起動:
```bash
vagrant up
```

2. アプリケーションは自動的に起動します

3. ログを確認:
```bash
vagrant ssh
docker logs -f nodejs
```

### ローカル開発

```bash
# 依存関係のインストール
pnpm install

# アプリケーション起動
pnpm start
```

## プロジェクト構造

```
playbooks/app/
├── package.json       # 依存関係とスクリプト定義
├── README.md          # このファイル
└── src/
    └── index.js       # メインアプリケーション
```

## 起動プロセス

Docker コンテナ内で以下のコマンドが順次実行されます：

1. `pnpm install` - 依存パッケージのインストール
2. `pnpm build` - ビルド（今回は不要）
3. `pnpm start` - アプリケーション起動（`node src/index.js`）

## ログ確認

```bash
# コンテナログを確認
docker logs nodejs

# リアルタイムでログを追跡
docker logs -f nodejs
```

## トラブルシューティング

### アプリケーションが起動しない
- コンテナログを確認: `docker logs nodejs`
- コンテナが実行中か確認: `docker ps | grep nodejs`
- コンテナを再起動: `docker restart nodejs`

### ポート3000に接続できない
- Nginxコンテナが起動しているか確認: `docker ps | grep nginx`
- Nginxの設定を確認: `docker exec nginx cat /etc/nginx/conf.d/default.conf`

## カスタマイズ

`src/index.js` を編集して、独自のエンドポイントやミドルウェアを追加できます。

### 新しいエンドポイントの追加例

```javascript
app.get('/api/users', (req, res) => {
  res.json({
    users: [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' }
    ]
  });
});
```
