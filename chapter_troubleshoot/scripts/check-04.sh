#!/bin/bash

# シナリオ4: PodがPendingのまま起動しない - チェックスクリプト

set -e

NAMESPACE="troubleshoot"
APP_LABEL="app=app-scheduling"

echo "=========================================="
echo "シナリオ4: スケジューリングチェック"
echo "=========================================="
echo ""

# Podの存在確認
if ! kubectl get pods -n $NAMESPACE -l $APP_LABEL &>/dev/null; then
    echo "❌ Podが見つかりません"
    echo ""
    echo "【ヒント】"
    echo "- セットアップスクリプトを実行してください:"
    echo "  ./scripts/setup-04-scheduling.sh"
    echo ""
    echo "- または手動でセットアップ:"
    echo "  1. NodeにTaintを設定:"
    echo "     kubectl taint nodes <node-name> workload=batch:NoSchedule"
    echo "  2. マニフェストを適用:"
    echo "     kubectl apply -f manifests/04-scheduling.yaml"
    exit 1
fi

# Podの状態を取得
POD_NAME=$(kubectl get pods -n $NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.nodeName}' 2>/dev/null)

echo "Pod名: $POD_NAME"
echo "状態: $POD_STATUS"
if [ -n "$NODE_NAME" ]; then
    echo "スケジュール先Node: $NODE_NAME"
fi
echo ""

# 成功判定
if [ "$POD_STATUS" = "Running" ] && [ -n "$NODE_NAME" ]; then
    echo "✅ 正解！PodがNodeにスケジュールされ、正常に起動しています"
    echo ""
    echo "【確認】Podがどのノードにスケジュールされたか確認:"
    kubectl get pod $POD_NAME -n $NAMESPACE -o wide
    echo ""
    echo "【確認】Podのtolerationが正しく設定されています:"
    kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.tolerations}' | jq .
    exit 0
fi

# Pending状態の場合
if [ "$POD_STATUS" = "Pending" ]; then
    echo "❌ PodがPending状態のままスケジュールされていません"
    echo ""
    echo "【現在の問題】"

    # スケジューリング失敗の理由を取得
    SCHEDULING_MSG=$(kubectl describe pod $POD_NAME -n $NAMESPACE 2>/dev/null | grep -A 3 "Events:" | tail -1)

    if kubectl describe pod $POD_NAME -n $NAMESPACE 2>/dev/null | grep -q "node(s) had untolerated taint"; then
        echo "NodeのTaintをPodがTolerateできていません。"
        echo ""

        # NodeのTaintを確認
        echo "【Nodeに設定されているTaint】"
        TAINTED_NODES=$(kubectl get nodes -o json | jq -r '.items[] | select(.spec.taints != null) | .metadata.name + ": " + (.spec.taints | map(.key + "=" + .value + ":" + .effect) | join(", "))')
        if [ -n "$TAINTED_NODES" ]; then
            echo "$TAINTED_NODES"
        else
            echo "※ Taintが設定されているNodeが見つかりません"
            echo "  セットアップスクリプトを実行してください:"
            echo "  ./scripts/setup-04-scheduling.sh"
        fi
        echo ""

        # PodのTolerationを確認
        echo "【Podに設定されているToleration】"
        kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.tolerations}' | jq .
        echo ""

        echo "【ヒント】"
        echo "1. NodeのTaintとPodのTolerationのeffectが一致していません"
        echo "2. マニフェストの tolerations セクションを確認してください:"
        echo "   - key: 'workload'"
        echo "   - value: 'batch'"
        echo "   - effect: ??? (NodeのTaintと一致させる必要があります)"
        echo ""
        echo "3. effectの種類:"
        echo "   - NoSchedule: 新しいPodをスケジュールしない"
        echo "   - NoExecute: 既存のPodも退避させる"
        echo "   - PreferNoSchedule: 可能な限りスケジュールしない"
    else
        echo "スケジューリングに失敗しています。"
        echo ""
        echo "【ヒント】"
        echo "詳細なイベントを確認してください:"
        echo "kubectl describe pod $POD_NAME -n $NAMESPACE"
    fi
else
    echo "❌ Podが起動していません"
    echo ""
    echo "【ヒント】"
    echo "Podの詳細を確認してください:"
    echo "kubectl describe pod $POD_NAME -n $NAMESPACE"
fi

exit 1
