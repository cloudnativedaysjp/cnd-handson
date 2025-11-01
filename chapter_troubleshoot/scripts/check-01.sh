#!/bin/bash

# シナリオ1: 環境変数が読み込めずPodが起動しない - チェックスクリプト

set -e

NAMESPACE="troubleshoot"
APP_LABEL="app=app-configmap"

echo "=========================================="
echo "シナリオ1: 環境変数チェック"
echo "=========================================="
echo ""

# Podの存在確認
if ! kubectl get pods -n $NAMESPACE -l $APP_LABEL &>/dev/null; then
    echo "❌ Podが見つかりません"
    echo ""
    echo "【ヒント】"
    echo "- まず、マニフェストを適用してください:"
    echo "  kubectl apply -f manifests/01-configmap.yaml"
    exit 1
fi

# Podの状態を取得
POD_NAME=$(kubectl get pods -n $NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
POD_READY=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

echo "Pod名: $POD_NAME"
echo "状態: $POD_STATUS"
echo ""

# 成功判定
if [ "$POD_STATUS" = "Running" ] && [ "$POD_READY" = "True" ]; then
    echo "✅ 正解！Podが正常に起動しています"
    echo ""
    echo "【確認】環境変数が正しく設定されているか確認してみましょう:"
    echo "kubectl logs $POD_NAME -n $NAMESPACE | grep -E 'DB_HOST|LOG_LEVEL'"
    echo ""
    kubectl logs $POD_NAME -n $NAMESPACE 2>/dev/null | grep -E "DB_HOST|LOG_LEVEL" || true
    exit 0
fi

# エラー判定とヒント
if kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null | grep -q "CreateContainerConfigError"; then
    echo "❌ ConfigMapの参照エラーが発生しています"
    echo ""
    echo "【現在の問題】"
    echo "Podが環境変数を読み込めていません。ConfigMapのキー名またはConfigMap名が間違っている可能性があります。"
    echo ""
    echo "【ヒント】"
    echo "1. ConfigMapのキー一覧を確認:"
    echo "   kubectl describe configmap config -n $NAMESPACE"
    echo ""
    echo "2. Podの詳細を確認してどのキーが見つからないか確認:"
    echo "   kubectl describe pod $POD_NAME -n $NAMESPACE"
    echo ""
    echo "3. マニフェストの env セクションで、configMapKeyRef の name と key を確認"
    echo "   - ConfigMap名が正しいか (config)"
    echo "   - キー名がConfigMapに存在するキーと一致しているか"
else
    echo "❌ Podが起動していません"
    echo ""
    echo "【ヒント】"
    echo "Podの詳細を確認してエラー内容を確認してください:"
    echo "kubectl describe pod $POD_NAME -n $NAMESPACE"
fi

exit 1
