#!/bin/bash

# シナリオ2: Podが何度も再起動を繰り返す - チェックスクリプト

set -e

NAMESPACE="troubleshoot"
APP_LABEL="app=app-oom"

echo "=========================================="
echo "シナリオ2: OOMチェック"
echo "=========================================="
echo ""

# Podの存在確認
if ! kubectl get pods -n $NAMESPACE -l $APP_LABEL &>/dev/null; then
    echo "❌ Podが見つかりません"
    echo ""
    echo "【ヒント】"
    echo "- まず、マニフェストを適用してください:"
    echo "  kubectl apply -f manifests/02-oom.yaml"
    exit 1
fi

# Podの状態を取得
POD_NAME=$(kubectl get pods -n $NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
RESTART_COUNT=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
LAST_STATE=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)

echo "Pod名: $POD_NAME"
echo "状態: $POD_STATUS"
echo "再起動回数: $RESTART_COUNT"
echo ""

# 成功判定
if [ "$POD_STATUS" = "Running" ] && [ "$RESTART_COUNT" = "0" ]; then
    echo "✅ 正解！Podが正常に起動して安定稼働しています"
    echo ""
    echo "【確認】メモリ使用量を確認してみましょう:"
    echo "kubectl top pod $POD_NAME -n $NAMESPACE"
    echo ""
    if kubectl top pod $POD_NAME -n $NAMESPACE 2>/dev/null; then
        echo ""
        echo "リソース制限:"
        kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources}' | jq .
    else
        echo "※ kubectl top を使用するには Metrics Server が必要です"
    fi
    exit 0
fi

# エラー判定とヒント
if [ "$LAST_STATE" = "OOMKilled" ] || kubectl describe pod $POD_NAME -n $NAMESPACE 2>/dev/null | grep -q "OOMKilled"; then
    echo "❌ OOM (Out Of Memory) Killerによって終了されています"
    echo ""
    echo "【現在の問題】"
    echo "アプリケーションが使用するメモリが、設定されたメモリ制限を超えています。"
    echo ""

    # 現在のリソース制限を表示
    MEMORY_LIMIT=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null)
    MEMORY_REQUEST=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null)

    echo "【現在の設定】"
    echo "メモリ request: $MEMORY_REQUEST"
    echo "メモリ limit: $MEMORY_LIMIT"
    echo ""
    echo "【ヒント】"
    echo "1. アプリケーションは約256MBのメモリを必要としています"
    echo "2. マニフェストの resources セクションを修正してください:"
    echo "   - requests.memory: 256Mi 以上に設定"
    echo "   - limits.memory: 512Mi 以上に設定"
    echo ""
    echo "3. Podの詳細を確認:"
    echo "   kubectl describe pod $POD_NAME -n $NAMESPACE"
elif [ "$RESTART_COUNT" -gt "0" ]; then
    echo "⚠️  Podが再起動しています (再起動回数: $RESTART_COUNT)"
    echo ""
    echo "【ヒント】"
    echo "再起動の理由を確認してください:"
    echo "kubectl describe pod $POD_NAME -n $NAMESPACE"
    echo ""
    echo "前回のログを確認:"
    echo "kubectl logs $POD_NAME -n $NAMESPACE --previous"
else
    echo "❌ Podが正常に起動していません"
    echo ""
    echo "【ヒント】"
    echo "Podの詳細を確認してください:"
    echo "kubectl describe pod $POD_NAME -n $NAMESPACE"
fi

exit 1
