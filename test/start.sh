#!/bin/bash

# 環境変数の確認
if [ -z "${REPO_USER}" ] || [ -z "${REPO_NAME}" ]; then
    echo "Error: REPO_USER and REPO_NAME must be set."
    exit 1
fi

# 渡された環境変数を使って script/start.sh を実行
curl -fsSL https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/master/script/start.sh | REPO_USER=${REPO_USER} REPO_NAME=${REPO_NAME} bash -s -- -test
