#!/bin/bash

# シナリオ3: コンテナイメージが取得できない - チェックスクリプト

set -e

NAMESPACE="troubleshoot"
APP_LABEL="app=app-image-pull"

echo "=========================================="
echo "シナリオ3: イメージプルチェック"
echo "=========================================="
echo ""

# Podの存在確認
if ! kubectl get pods -n $NAMESPACE -l $APP_LABEL &>/dev/null; then
    echo "❌ Podが見つかりません"
    echo ""
    echo "【ヒント】"
    echo "- まず、マニフェストを適用してください:"
    echo "  kubectl apply -f manifests/03-image_pull.yaml"
    exit 1
fi

# Podの状態を取得
POD_NAME=$(kubectl get pods -n $NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
POD_READY=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
IMAGE=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)

echo "Pod名: $POD_NAME"
echo "状態: $POD_STATUS"
echo "イメージ: $IMAGE"
echo ""

# 成功判定
if [ "$POD_STATUS" = "Running" ] && [ "$POD_READY" = "True" ]; then
    echo "✅ 正解！Podが正常に起動しています"
    echo ""
    echo "【確認】イメージが正しくPullされ、nginxが動作しています"
    echo ""
    echo "Podの詳細:"
    kubectl get pod $POD_NAME -n $NAMESPACE -o wide
    exit 0
fi

# エラー判定とヒント
WAITING_REASON=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)

if [ "$WAITING_REASON" = "ImagePullBackOff" ] || [ "$WAITING_REASON" = "ErrImagePull" ]; then
    echo "❌ イメージのPullに失敗しています"
    echo ""
    echo "【現在の問題】"
    echo "指定されたコンテナイメージが見つかりません。"
    echo ""

    # エラーメッセージを取得
    ERROR_MSG=$(kubectl describe pod $POD_NAME -n $NAMESPACE 2>/dev/null | grep -A 5 "Failed to pull image" || echo "")

    if echo "$ERROR_MSG" | grep -q "manifest unknown"; then
        echo "【詳細】"
        echo "イメージのタグが存在しません (manifest unknown)"
        echo ""
        echo "【原因】"
        echo "Bitnamiは2024年頃から特定バージョンのタグを削除するポリシーに変更しました。"
        echo "以前使えていたタグ (例: bitnami/nginx:1.25.0) が削除されている可能性があります。"
        echo ""
        echo "【ヒント - 解決策1】公式イメージを使用する（推奨）"
        echo "  image: nginx:1.27  # 公式のnginxイメージに変更"
        echo "  ports:"
        echo "  - containerPort: 80  # ポートも80に変更"
        echo ""
        echo "【ヒント - 解決策2】Bitnamiのlatestタグを使用"
        echo "  image: bitnami/nginx:latest"
        echo "  ※ 本番環境では非推奨（バージョンが固定されないため）"
    else
        echo "【ヒント】"
        echo "1. イメージ名とタグが正しいか確認してください"
        echo "2. エラーの詳細を確認:"
        echo "   kubectl describe pod $POD_NAME -n $NAMESPACE"
    fi
    echo ""
    echo "【参考】"
    echo "https://qiita.com/m-masataka/items/73383c77cf2e2b8592f0"
else
    echo "❌ Podが起動していません"
    echo ""
    echo "【ヒント】"
    echo "Podの詳細を確認してエラー内容を確認してください:"
    echo "kubectl describe pod $POD_NAME -n $NAMESPACE"
fi

exit 1
