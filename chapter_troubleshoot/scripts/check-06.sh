#!/bin/bash

# シナリオ6: 総合問題 - チェックスクリプト

set -e

NAMESPACE="troubleshoot"
INGRESS_NAME="cnd-web-ing"

echo "=========================================="
echo "シナリオ6: 総合問題チェック"
echo "=========================================="
echo ""

# リソースの存在確認
if ! kubectl get namespace $NAMESPACE &>/dev/null; then
    echo "❌ troubleshoot namespaceが見つかりません"
    echo ""
    echo "【ヒント】"
    echo "- まず、マニフェストを適用してください:"
    echo "  kubectl apply -f manifests/06-cnd-web.yaml"
    exit 1
fi

echo "【リソース状態】"
echo ""

# Secretの確認
echo "1. Secret:"
if kubectl get secret app-secret -n $NAMESPACE &>/dev/null; then
    echo "   ✓ app-secret が存在します"
    DB_PASSWORD_ENCODED=$(kubectl get secret app-secret -n $NAMESPACE -o jsonpath='{.data.DB_PASSWORD}' 2>/dev/null)
    if [ "$DB_PASSWORD_ENCODED" = "cGFzc3dvcmQ=" ]; then
        echo "   ✓ DB_PASSWORD が正しく設定されています"
    elif [ "$DB_PASSWORD_ENCODED" = "<base64-encoded-password>" ]; then
        echo "   ✗ DB_PASSWORD がプレースホルダーのままです"
    else
        echo "   ? DB_PASSWORD: $DB_PASSWORD_ENCODED"
    fi
else
    echo "   ✗ app-secret が存在しません"
fi
echo ""

# MySQLの確認
echo "2. MySQL Pod:"
if kubectl get pod mysql -n $NAMESPACE &>/dev/null; then
    MYSQL_STATUS=$(kubectl get pod mysql -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$MYSQL_STATUS" = "Running" ]; then
        echo "   ✓ mysql Pod が Running です"
    else
        echo "   ✗ mysql Pod の状態: $MYSQL_STATUS"
    fi
else
    echo "   ✗ mysql Pod が存在しません"
fi
echo ""

# cnd-web-appの確認
echo "3. cnd-web-app Pod:"
if kubectl get pod cnd-web-app -n $NAMESPACE &>/dev/null; then
    CND_WEB_STATUS=$(kubectl get pod cnd-web-app -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$CND_WEB_STATUS" = "Running" ]; then
        echo "   ✓ cnd-web-app Pod が Running です"
    else
        echo "   ✗ cnd-web-app Pod の状態: $CND_WEB_STATUS"
    fi
else
    echo "   ✗ cnd-web-app Pod が存在しません"
fi
echo ""

# Serviceの確認
echo "4. Services:"
if kubectl get svc mysql-svc -n $NAMESPACE &>/dev/null; then
    echo "   ✓ mysql-svc が存在します"
else
    echo "   ✗ mysql-svc が存在しません"
fi

if kubectl get svc cnd-web-svc -n $NAMESPACE &>/dev/null; then
    echo "   ✓ cnd-web-svc が存在します"
    # Selectorの確認
    SELECTOR=$(kubectl get svc cnd-web-svc -n $NAMESPACE -o jsonpath='{.spec.selector}' 2>/dev/null)
    if echo "$SELECTOR" | grep -q "cnd-web"; then
        echo "   ✓ cnd-web-svc のselectorが正しく設定されています"
    else
        echo "   ✗ cnd-web-svc のselectorに問題がある可能性があります"
    fi
else
    echo "   ✗ cnd-web-svc が存在しません"
fi
echo ""

# Ingressの確認
echo "5. Ingress:"
if kubectl get ingress $INGRESS_NAME -n $NAMESPACE &>/dev/null; then
    echo "   ✓ cnd-web-ing が存在します"
    INGRESS_HOST=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
    echo "   Host: $INGRESS_HOST"
else
    echo "   ✗ cnd-web-ing が存在しません"
fi
echo ""

# 全体の判定
ALL_RUNNING=true

# 全てのPodがRunningか確認
for pod in mysql cnd-web-app; do
    STATUS=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$STATUS" != "Running" ]; then
        ALL_RUNNING=false
        break
    fi
done

# Secretが正しく設定されているか確認
if [ "$DB_PASSWORD_ENCODED" != "cGFzc3dvcmQ=" ]; then
    ALL_RUNNING=false
fi

if [ "$ALL_RUNNING" = true ]; then
    echo "=========================================="
    echo "✅ 正解！全てのリソースが正常に動作しています"
    echo "=========================================="
    echo ""
    echo "【最終確認】"
    echo "ブラウザまたはcurlでアクセスして、Webページが表示されるか確認してください:"
    echo ""
    echo "1. /etc/hostsに以下を追加 (必要に応じて):"
    echo "   <ingress-ip> cnd-web.example.com"
    echo ""
    echo "2. アクセス確認:"
    echo "   curl -H 'Host: cnd-web.example.com' http://cnd-web.example.com/"
    echo "   または"
    echo "   ブラウザで http://cnd-web.example.com/ にアクセス"
    exit 0
fi

echo "=========================================="
echo "❌ まだ問題が残っています"
echo "=========================================="
echo ""
echo "【デバッグ方法】"
echo ""
echo "1. Podの状態を確認:"
echo "   kubectl get pods -n $NAMESPACE"
echo ""
echo "2. 各Podの詳細を確認:"
echo "   kubectl describe pod mysql -n $NAMESPACE"
echo "   kubectl describe pod cnd-web-app -n $NAMESPACE"
echo ""
echo "3. ログを確認:"
echo "   kubectl logs mysql -n $NAMESPACE"
echo "   kubectl logs cnd-web-app -n $NAMESPACE"
echo ""
echo "4. Serviceの確認:"
echo "   kubectl get svc -n $NAMESPACE"
echo "   kubectl describe svc mysql-svc -n $NAMESPACE"
echo "   kubectl describe svc cnd-web-svc -n $NAMESPACE"
echo ""
echo "5. Ingressの確認:"
echo "   kubectl describe ingress $INGRESS_NAME -n $NAMESPACE"
echo ""
echo "【よくある問題】"
echo "- Secretの DB_PASSWORD がプレースホルダー (<base64-encoded-password>) のままになっていませんか?"
echo "  → 実際のBase64エンコードされた値に変更してください (例: cGFzc3dvcmQ=)"
echo ""
echo "- Podが起動していない場合、describe で Events を確認してください"
echo ""
echo "- 構成図とエラーメッセージがヒントになります"

exit 1
