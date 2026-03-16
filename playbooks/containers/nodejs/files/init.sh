#!/bin/bash
set -e

echo "Starting application initialization..."

# パッケージのインストール
echo "Installing packages..."
cd /app
pnpm install

# アプリケーションのビルド
echo "Building application..."
pnpm build

# アプリケーション起動
echo "Starting application..."
exec pnpm start
