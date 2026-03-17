> [!WARNING]
> このリポジトリは現在プロトタイプ開発のためのテスト用です。本番環境での使用は想定していません。

# 1行でDockerサーバ環境構築

サーバに`root`ログインし１行のコマンドを実行するだけでDocker環境が構築できるスクリプトです。

## 対象OS

- Ubuntu 24

## ライセンス

[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://lbesson.mit-license.org/)

# 内容

AnsibleのローカルでDocker環境を構築し、NodeBBを動かすためのコンテナ群をセットアップします。

## 構築内容

- `geerlingguy.docker` (Ansible Galaxy ロール) で Docker をインストール
- `zip`, `unzip`, `inotify-tools` をインストール
- 日本語環境のセットアップ
- 以下のDockerコンテナを構築:
  - **Redis** - セッション・キャッシュストア
  - **MariaDB** - データベース
  - **Nginx** - リバースプロキシ
  - **Node.js** - NodeBBアプリケーション実行環境

# 使い方

新規にOSをインストールしたサーバに`root`でログインし、以下の１行のコマンドをそのままコピーして実行します。

## 実行コマンド

最新のリリースタグを使用して実行します。

```bash
curl -fsSL https://raw.githubusercontent.com/kdinstall/docker-nodebb/master/script/start.sh | REPO_USER=kdinstall REPO_NAME=docker-nodebb bash
```

> **注意:** デフォルトでは GitHub の最新リリースタグが自動的に取得・使用されます。  
> 開発中の最新コードを使いたい場合は、後述のテスト実行コマンドを使用してください。

### 設定の永続化

初回実行時にドメイン名とメールアドレスを入力すると、`/etc/kdinstall/config` に保存されます。  
2回目以降の実行では、保存された設定が自動的に読み込まれ、確認メッセージが表示されます。

```bash
# 2回目以降は保存された設定を使用
curl -fsSL https://raw.githubusercontent.com/kdinstall/docker-nodebb/master/script/start.sh | REPO_USER=kdinstall REPO_NAME=docker-nodebb bash

# 設定を変更したい場合
curl -fsSL https://raw.githubusercontent.com/kdinstall/docker-nodebb/master/script/start.sh | REPO_USER=kdinstall REPO_NAME=docker-nodebb bash -s -- --reconfigure
```

オプション（`bash -s --` 経由で渡す）:

| オプション | 説明 |
|---|---------|
| `--help` | ヘルプを表示 |
| `--reconfigure` | 保存された設定を無視して再入力 |

## テスト実行

最新の master ブランチを使用してテスト実行する場合は、テスト用スクリプトを使用します。

```bash
curl -fsSL https://raw.githubusercontent.com/kdinstall/docker-nodebb/master/test/start.sh | REPO_USER=kdinstall REPO_NAME=docker-nodebb bash
```

> **注意:** `REPO_USER` と `REPO_NAME` の両方が必須です。未設定の場合はエラーで終了します。