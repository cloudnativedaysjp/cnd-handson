#!/bin/bash

# シナリオ5: Ingressで503エラーが発生する - チェックスクリプト

set -e

NAMESPACE="troubleshoot"
INGRESS_NAME="ingress"
FRONTEND_NS="frontend"
BACKEND_NS="backend"

echo "=========================================="
echo "シナリオ5: Ingressチェック"
echo "=========================================="
echo ""

# Ingressの存在確認
if ! kubectl get ingress $INGRESS_NAME -n $NAMESPACE &>/dev/null; then
    echo "❌ Ingressが見つかりません"
    echo ""
    echo "【ヒント】"
    echo "- まず、マニフェストを適用してください:"
    echo "  kubectl apply -f manifests/05-ingress.yaml"
    exit 1
fi

echo "【リソース確認】"
echo ""

# 各namespaceのPod状態を確認
echo "Frontend Podの状態:"
kubectl get pods -n $FRONTEND_NS -l app=app-frontend 2>/dev/null || echo "  Podが見つかりません"
echo ""

echo "Backend Podの状態:"
kubectl get pods -n $BACKEND_NS -l app=app-backend 2>/dev/null || echo "  Podが見つかりません"
echo ""

echo "Troubleshoot namespaceのService:"
kubectl get svc -n $NAMESPACE 2>/dev/null || echo "  Serviceが見つかりません"
echo ""

# ExternalName Serviceの存在確認
FRONTEND_SVC_EXISTS=$(kubectl get svc frontend-app -n $NAMESPACE --ignore-not-found 2>/dev/null)
BACKEND_SVC_EXISTS=$(kubectl get svc backend-app -n $NAMESPACE --ignore-not-found 2>/dev/null)

# 成功判定
if [ -n "$FRONTEND_SVC_EXISTS" ] && [ -n "$BACKEND_SVC_EXISTS" ]; then
    FRONTEND_SVC_TYPE=$(kubectl get svc frontend-app -n $NAMESPACE -o jsonpath='{.spec.type}' 2>/dev/null)
    BACKEND_SVC_TYPE=$(kubectl get svc backend-app -n $NAMESPACE -o jsonpath='{.spec.type}' 2>/dev/null)

    if [ "$FRONTEND_SVC_TYPE" = "ExternalName" ] && [ "$BACKEND_SVC_TYPE" = "ExternalName" ]; then
        echo "✅ 正解！ExternalName Serviceが正しく設定されています"
        echo ""
        echo "【確認】Service詳細:"
        echo ""
        echo "frontend-app Service:"
        kubectl get svc frontend-app -n $NAMESPACE -o yaml | grep -A 5 "spec:"
        echo ""
        echo "backend-app Service:"
        kubectl get svc backend-app -n $NAMESPACE -o yaml | grep -A 5 "spec:"
        echo ""
        echo "【接続確認】"
        echo "Ingressを経由してアクセスできるか確認してください:"
        echo ""
        echo "1. /etc/hostsに以下を追加 (必要に応じて):"
        echo "   <ingress-ip> troubleshoot.example.com"
        echo ""
        echo "2. curlで確認:"
        echo "   curl -H 'Host: troubleshoot.example.com' http://troubleshoot.example.com/"
        echo "   curl -H 'Host: troubleshoot.example.com' http://troubleshoot.example.com/api"
        exit 0
    fi
fi

# エラー判定とヒント
echo "❌ Ingressが正しく設定されていません"
echo ""
echo "【現在の問題】"

if [ -z "$FRONTEND_SVC_EXISTS" ] && [ -z "$BACKEND_SVC_EXISTS" ]; then
    echo "troubleshoot namespaceに frontend-app と backend-app のServiceが存在しません。"
    echo ""
    echo "【原因】"
    echo "Ingressは同じnamespace内のServiceしか参照できません。"
    echo "現在、Ingressはtroubleshot namespaceにありますが、"
    echo "実際のアプリケーションServiceは frontend と backend namespaceにあります。"
    echo ""
    echo "【ヒント】"
    echo "ExternalName Serviceを使用して、異なるnamespaceのServiceを参照できるようにします。"
    echo ""
    echo "troubleshoot namespaceに以下のServiceを追加してください:"
    echo ""
    echo "---"
    echo "apiVersion: v1"
    echo "kind: Service"
    echo "metadata:"
    echo "  name: frontend-app"
    echo "  namespace: troubleshoot"
    echo "spec:"
    echo "  type: ExternalName"
    echo "  externalName: app-frontend.frontend.svc.cluster.local"
    echo "  ports:"
    echo "  - port: 80"
    echo "---"
    echo "apiVersion: v1"
    echo "kind: Service"
    echo "metadata:"
    echo "  name: backend-app"
    echo "  namespace: troubleshoot"
    echo "spec:"
    echo "  type: ExternalName"
    echo "  externalName: app-backend.backend.svc.cluster.local"
    echo "  ports:"
    echo "  - port: 8080"
elif [ -n "$FRONTEND_SVC_EXISTS" ] && [ "$FRONTEND_SVC_TYPE" != "ExternalName" ]; then
    echo "frontend-app Serviceが存在しますが、タイプがExternalNameではありません。"
    echo ""
    echo "【ヒント】"
    echo "Service typeを ExternalName に変更してください。"
elif [ -n "$BACKEND_SVC_EXISTS" ] && [ "$BACKEND_SVC_TYPE" != "ExternalName" ]; then
    echo "backend-app Serviceが存在しますが、タイプがExternalNameではありません。"
    echo ""
    echo "【ヒント】"
    echo "Service typeを ExternalName に変更してください。"
else
    echo "一部のServiceが不足しています。"
    echo ""
    echo "【ヒント】"
    echo "Ingressの詳細を確認してください:"
    echo "kubectl describe ingress $INGRESS_NAME -n $NAMESPACE"
fi

echo ""
echo "【参考】各namespaceのService一覧:"
echo ""
echo "troubleshoot namespace:"
kubectl get svc -n $NAMESPACE
echo ""
echo "frontend namespace:"
kubectl get svc -n $FRONTEND_NS
echo ""
echo "backend namespace:"
kubectl get svc -n $BACKEND_NS

exit 1
