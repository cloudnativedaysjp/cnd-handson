# Envoy Gateway
本chapterではEnvoy Gatewayを使って、Gateway APIによるHTTPルーティングやBackendリソースを用いた外部サービスへのルーティングを体験します。

## 目次
- [概要](#概要)
- [セットアップ](#セットアップ)
- [基本的なHTTPルーティング](#基本的なhttpルーティング)
- [パスベースルーティング](#パスベースルーティング)
- [ヘッダーベースルーティング](#ヘッダーベースルーティング)
- [トラフィックの重み付けルーティング](#トラフィックの重み付けルーティング)
- [Backendリソースによる外部ルーティング](#backendリソースによる外部ルーティング)
- [BackendTrafficPolicyによるヘルスチェック](#backendtrafficpolicyによるヘルスチェック)
- [Tips: egctlを使ったデバッグ](#tips-egctlを使ったデバッグ)
- [クリーンアップ](#クリーンアップ)

## 概要
### Envoy Gatewayとは
Envoy Gatewayは、[Gateway API](https://gateway-api.sigs.k8s.io/)に準拠したAPI Gatewayの実装です。内部的にはEnvoy Proxyを利用しており、ControllerがGateway APIリソースからEnvoyの設定を生成し、xDS (x Discovery Service)でProxyに配信する仕組みになっています。

Envoy Gatewayは当初North-South(外部からクラスタ内部への通信)のトラフィック管理を主な目的として設計されていましたが、v1.2以降ではEast-West(サービス間通信)のサポートも追加され、IngressとService Meshの両方を統合的に管理できるプロジェクトへと進化しています。

### Istioとの違い
同じくEnvoyを基盤とするIstioとよく比較されますが、それぞれ異なるユースケースを持っています。

| | Envoy Gateway | Istio |
|---|---|---|
| 主な用途 | API Gateway / Ingress (North-South) | サービスメッシュ (East-West) |
| API | Gateway API + 拡張CRD | Gateway API + 独自CRD(VirtualService等) |
| データプレーン | Gateway単位でEnvoy Proxyを配置 | Pod単位でEnvoy Sidecarを注入 |
| 導入の容易さ | シンプル | 多機能だが複雑 |

### Gateway APIとは
Gateway APIは、Kubernetes上でトラフィックルーティングを管理するための標準的なAPIです。従来のIngress APIの後継として設計され、よりリッチなルーティング機能と拡張性を提供します。

主なリソースは以下のとおりです。

- **GatewayClass**: Gatewayを管理するControllerを定義するクラスタスコープのリソース
- **Gateway**: ロードバランサなどのインフラを設定するリソース。Listenerでポートやプロトコルを定義
- **HTTPRoute**: HTTPトラフィックのルーティングルールを定義するリソース。パス、ヘッダー、重み付けなどの条件でルーティング可能

### Envoy Gateway固有のリソース
Envoy Gatewayは、Gateway API標準のリソースに加えて独自の拡張リソースを提供しています。

- **Backend**: Kubernetesネイティブリソース以外の宛先(外部FQDN、IPアドレス等)へルーティングするためのリソース
- **BackendTrafficPolicy**: バックエンドへのトラフィックに対するヘルスチェック、リトライ、タイムアウト等のポリシーを定義するリソース
- **HTTPRouteFilter**: Cookie matchなど、標準のHTTPRouteでは対応していないフィルタリングを拡張するリソース

## 始める前に
- Kubernetesクラスターが作成されていること(まだの場合は[こちら](../chapter_cluster-create/README.md))

## セットアップ

この章での作業ディレクトリは以下です。

```sh
cd ~/cnd-handson/chapter_envoy-gateway/
```

### Envoy Gatewayのインストール

HelmでGateway API CRDとEnvoy Gatewayをインストールします。

```sh
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.7.1 -n envoy-gateway-system --create-namespace
```

Envoy Gatewayが正常に起動するまで待ちます。

```sh
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

```
# 実行結果
deployment.apps/envoy-gateway condition met
```

インストールされたリソースを確認します。

```sh
kubectl get deployments -n envoy-gateway-system
```

```
# 実行結果
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
envoy-gateway   1/1     1            1           60s
```

### アプリケーションとGatewayリソースのデプロイ

ハンズオン用のnamespace、テストアプリケーション(v1/v2)、GatewayClass、Gatewayリソースをデプロイします。

```sh
kubectl apply -f manifests/app.yaml
kubectl apply -f manifests/gatewayclass.yaml
kubectl apply -f manifests/gateway.yaml
```

Podが起動していることを確認します。

```sh
kubectl get pods -n envoy-gateway-handson
```

```
# 実行結果
NAME                      READY   STATUS    RESTARTS   AGE
app-v1-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
app-v2-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

GatewayリソースがProgrammedになっていることを確認します。

```sh
kubectl get gateway -n envoy-gateway-handson
```

```
# 実行結果
NAME   CLASS   ADDRESS         PROGRAMMED   AGE
eg     eg      x.x.x.x        True         30s
```

### Gatewayへのアクセス設定

GatewayのExternal IPを確認します。

```sh
kubectl get gateway eg -n envoy-gateway-handson
```

```
# 実行結果
NAME   CLASS   ADDRESS        PROGRAMMED   AGE
eg     eg      x.x.x.x       True         60s
```

`ADDRESS`に表示されたIPアドレスを`/etc/hosts`に設定します（[chapter_setup](../chapter_setup/README.md)で設定済みの場合は、IPアドレスを更新してください）。

```
GATEWAY_IP    app.envoy-gateway.example.com
```

> [!NOTE]
>
> 以降のセクションでは、`http://app.envoy-gateway.example.com:8080` でGatewayにアクセスすることを前提としています。

## 基本的なHTTPルーティング

まず、最も基本的なHTTPルーティングを設定します。すべてのリクエストをapp-v1にルーティングします。

HTTPRouteのマニフェストを確認します。

```sh
cat manifests/httproute-basic.yaml
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: envoy-gateway-handson
spec:
  parentRefs:
    - name: eg
  hostnames:
    - "app.envoy-gateway.example.com"
  rules:
    - backendRefs:
        - name: app-v1
          port: 8080
      matches:
        - path:
            type: PathPrefix
            value: /
```

ポイントは以下のとおりです。
- `parentRefs`: このHTTPRouteがどのGatewayに紐づくかを指定
- `hostnames`: マッチするホスト名を指定
- `rules`: ルーティングルール。`matches`で条件を、`backendRefs`で転送先を定義

HTTPRouteをデプロイします。

```sh
kubectl apply -f manifests/httproute-basic.yaml
```

動作確認をします。

```sh
curl -s http://app.envoy-gateway.example.com:8081/
```

```
# 実行結果
Hello from v1
```

app-v1からレスポンスが返ってくることを確認できました。

次のセクションに進む前に、作成したHTTPRouteを削除します。

```sh
kubectl delete -f manifests/httproute-basic.yaml
```

## パスベースルーティング

次に、URLパスに基づいてトラフィックを異なるサービスにルーティングする設定を行います。

マニフェストを確認します。

```sh
cat manifests/httproute-path.yaml
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route-path
  namespace: envoy-gateway-handson
spec:
  parentRefs:
    - name: eg
  hostnames:
    - "app.envoy-gateway.example.com"
  rules:
    - backendRefs:
        - name: app-v1
          port: 8080
      matches:
        - path:
            type: PathPrefix
            value: /v1
    - backendRefs:
        - name: app-v2
          port: 8080
      matches:
        - path:
            type: PathPrefix
            value: /v2
```

`/v1`へのリクエストはapp-v1に、`/v2`へのリクエストはapp-v2にルーティングされます。

HTTPRouteをデプロイし、動作確認をします。

```sh
kubectl apply -f manifests/httproute-path.yaml
```

```sh
curl -s http://app.envoy-gateway.example.com:8080/v1
```

```
# 実行結果
Hello from v1
```

```sh
curl -s http://app.envoy-gateway.example.com:8080/v2
```

```
# 実行結果
Hello from v2
```

パスに応じて異なるサービスにルーティングされていることを確認できました。

次のセクションに進む前に、作成したHTTPRouteを削除します。

```sh
kubectl delete -f manifests/httproute-path.yaml
```

## ヘッダーベースルーティング

HTTPリクエストヘッダーの値に基づいてルーティングを制御します。これはカナリアリリースなどで活用できるパターンです。

マニフェストを確認します。

```sh
cat manifests/httproute-header.yaml
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route-header
  namespace: envoy-gateway-handson
spec:
  parentRefs:
    - name: eg
  hostnames:
    - "app.envoy-gateway.example.com"
  rules:
    - backendRefs:
        - name: app-v2
          port: 8080
      matches:
        - headers:
            - name: x-version
              value: canary
    - backendRefs:
        - name: app-v1
          port: 8080
      matches:
        - path:
            type: PathPrefix
            value: /
```

`x-version: canary`ヘッダーがあるリクエストはapp-v2に、それ以外はapp-v1にルーティングされます。HTTPRouteでは、より具体的なルールが優先されるため、ヘッダーマッチのルールがパスマッチよりも先に評価されます。

HTTPRouteをデプロイし、動作確認をします。

```sh
kubectl apply -f manifests/httproute-header.yaml
```

通常のリクエスト:

```sh
curl -s http://app.envoy-gateway.example.com:8080/
```

```
# 実行結果
Hello from v1
```

canaryヘッダーを付与したリクエスト:

```sh
curl -s --header "x-version: canary" http://app.envoy-gateway.example.com:8080/
```

```
# 実行結果
Hello from v2
```

ヘッダーの有無によって、ルーティング先が変わることを確認できました。

次のセクションに進む前に、作成したHTTPRouteを削除します。

```sh
kubectl delete -f manifests/httproute-header.yaml
```

## トラフィックの重み付けルーティング

複数のサービスに対してトラフィックを重み付けで分散させます。段階的なリリース(カナリアリリース)を行う際に有用です。

マニフェストを確認します。

```sh
cat manifests/httproute-weight.yaml
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route-weight
  namespace: envoy-gateway-handson
spec:
  parentRefs:
    - name: eg
  hostnames:
    - "app.envoy-gateway.example.com"
  rules:
    - backendRefs:
        - name: app-v1
          port: 8080
          weight: 80
        - name: app-v2
          port: 8080
          weight: 20
      matches:
        - path:
            type: PathPrefix
            value: /
```

app-v1に80%、app-v2に20%の割合でトラフィックが分散されます。

HTTPRouteをデプロイし、動作確認をします。

```sh
kubectl apply -f manifests/httproute-weight.yaml
```

10回リクエストを送って、トラフィックの分散を確認します。

```sh
for i in $(seq 1 10); do curl -s http://app.envoy-gateway.example.com:8080/; done
```

```
# 実行結果(概ね8:2の割合でレスポンスが分散される)
Hello from v1
Hello from v1
Hello from v1
Hello from v2
Hello from v1
Hello from v1
Hello from v1
Hello from v1
Hello from v2
Hello from v1
```

v1とv2のレスポンスが概ね80:20の割合で返ってくることを確認できました。

次のセクションに進む前に、作成したHTTPRouteを削除します。

```sh
kubectl delete -f manifests/httproute-weight.yaml
```

## Backendリソースによる外部ルーティング

ここからはEnvoy Gateway固有の機能を使います。Backendリソースを使うと、Kubernetes Serviceではなく外部のFQDNやIPアドレスに直接ルーティングできます。これにより、外部サービスへのルーティングのためにKubernetes ServiceやEndpointSliceを手動で管理する必要がなくなります。

> [!WARNING]
>
> Backend APIはセキュリティ上の理由からデフォルトで無効になっています。本番環境で使用する際は、Kubernetes RBACによるアクセス制御を適切に設定してください。

### Backend APIの有効化

まず、Backend APIを有効にするためにEnvoy Gatewayの設定を更新します。

```sh
kubectl apply -f manifests/enable-backend-configmap.yaml
```

設定を反映するため、Envoy Gatewayを再起動します。

```sh
kubectl rollout restart deployment envoy-gateway -n envoy-gateway-system
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

### 外部サービスへのルーティング

httpbin.orgという公開APIサービスにルーティングする設定を行います。

マニフェストを確認します。

```sh
cat manifests/backend.yaml
```

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata:
  name: httpbin
  namespace: envoy-gateway-handson
spec:
  endpoints:
    - fqdn:
        hostname: httpbin.org
        port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backend-route
  namespace: envoy-gateway-handson
spec:
  parentRefs:
    - name: eg
  hostnames:
    - "app.envoy-gateway.example.com"
  rules:
    - backendRefs:
        - group: gateway.envoyproxy.io
          kind: Backend
          name: httpbin
      matches:
        - path:
            type: PathPrefix
            value: /
```

ポイントは以下のとおりです。
- **Backend**リソースで外部サービスのFQDN(`httpbin.org`)とポートを指定
- **HTTPRoute**の`backendRefs`で`group`と`kind`を指定して、通常のKubernetes Serviceではなく、Envoy GatewayのBackendリソースを参照

デプロイして動作確認をします。

```sh
kubectl apply -f manifests/backend.yaml
```

Backendリソースが作成されたことを確認します。

```sh
kubectl get backend -n envoy-gateway-handson
```

```
# 実行結果
NAME      AGE
httpbin   10s
```

外部サービスにリクエストが転送されるか確認します。

```sh
curl -s http://app.envoy-gateway.example.com:8080/headers | head -20
```

```
# 実行結果(httpbin.orgからのレスポンスが返る)
{
  "headers": {
    "Accept": "*/*",
    "Host": "app.envoy-gateway.example.com",
    "User-Agent": "curl/8.x.x",
    "X-Envoy-External-Address": "xxx.xxx.xxx.xxx"
  }
}
```

`X-Envoy-External-Address`ヘッダーが含まれていることから、Envoy Proxyを経由して外部のhttpbin.orgにリクエストが転送されていることが分かります。

次のセクションに進む前に、作成したリソースを削除します。

```sh
kubectl delete -f manifests/backend.yaml
```

## BackendTrafficPolicyによるヘルスチェック

Envoy GatewayのBackendTrafficPolicyリソースを使うと、バックエンドに対するヘルスチェックを設定できます。Active(定期的にエンドポイントを確認)とPassive(実際のトラフィック応答を監視)の2種類のヘルスチェックに対応しています。

まず、基本的なHTTPRouteを再度デプロイします。

```sh
kubectl apply -f manifests/httproute-basic.yaml
```

BackendTrafficPolicyのマニフェストを確認します。

```sh
cat manifests/backend-traffic-policy.yaml
```

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: health-check-policy
  namespace: envoy-gateway-handson
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: app-route
  healthCheck:
    passive:
      baseEjectionTime: 10s
      interval: 2s
      maxEjectionPercent: 100
      consecutive5XxErrors: 3
      consecutiveLocalOriginFailures: 3
    active:
      type: HTTP
      timeout: 1s
      interval: 3s
      unhealthyThreshold: 3
      healthyThreshold: 1
      http:
        path: /healthz
        method: GET
        expectedStatuses:
          - 200
```

ポイントは以下のとおりです。
- `targetRefs`: ポリシーを適用するHTTPRouteを指定
- `passive`: 実際のトラフィック応答を監視。5xxエラーが3回連続すると、そのエンドポイントを10秒間除外
- `active`: 3秒ごとに`/healthz`エンドポイントにHTTP GETリクエストを送り、200が返るかチェック

BackendTrafficPolicyをデプロイします。

```sh
kubectl apply -f manifests/backend-traffic-policy.yaml
```

BackendTrafficPolicyが作成されたことを確認します。

```sh
kubectl get backendtrafficpolicy -n envoy-gateway-handson
```

```
# 実行結果
NAME                   AGE
health-check-policy    10s
```

これにより、ヘルスチェックに基づいてEnvoy Gatewayが自動的に異常なバックエンドをルーティング対象から除外するようになります。

## Tips: egctlを使ったデバッグ

Envoy Gatewayには`egctl`というCLIツールが用意されており、リソースのステータス確認やEnvoy Proxyの設定確認など、デバッグに役立つ機能を提供しています。

### egctlのインストール

```sh
curl -fsSL https://gateway.envoyproxy.io/get-egctl.sh | VERSION=v1.7.1 bash
sudo mv ./bin/egctl /usr/local/bin/
```

macOSの場合はHomebrewでもインストールできます。

```sh
brew install egctl
```

インストールを確認します。

```sh
egctl version
```

### リソースのステータス確認

`egctl x status`コマンドで、Envoy Gatewayが管理する各リソースのステータスをまとめて確認できます。ルーティングが期待通りに動かない場合、まずこのコマンドで全体の状態を把握するのがおすすめです。

GatewayClassのステータス確認:

```sh
egctl x status gatewayclass
```

```
# 実行結果
NAME   TYPE       STATUS    REASON    MESSAGE                       LAST TRANSITION TIME
eg     Accepted   True      Accepted  The GatewayClass is accepted  2025-01-01T00:00:00Z
```

全namespaceの全リソースのステータスをまとめて確認:

```sh
egctl x status all -A
```

HTTPRouteのステータスを詳細表示（`--verbose`で詳しい情報が見れます）:

```sh
egctl x status httproute --verbose -n envoy-gateway-handson
```

> [!NOTE]
>
> `egctl x status`の`x`は`experimental`の省略形です。

### Envoy Proxyの設定確認（xDS config dump）

`egctl config`コマンドで、Envoy Proxyに実際に配信されているxDS設定を確認できます。意図したルーティング設定がEnvoy Proxyに正しく反映されているかデバッグする際に有用です。

Routeの設定を確認:

```sh
egctl config envoy-proxy route -n envoy-gateway-system
```

Clusterの設定を確認:

```sh
egctl config envoy-proxy cluster -n envoy-gateway-system
```

Listenerの設定を確認:

```sh
egctl config envoy-proxy listener -n envoy-gateway-system
```

### Gateway APIリソースのxDS変換（translate）

`egctl x translate`コマンドを使うと、Gateway APIリソースが実際にどのようなxDS設定に変換されるかを事前に確認できます。マニフェストをapplyする前にドライランとして活用できます。

```sh
cat manifests/httproute-basic.yaml manifests/gateway.yaml manifests/gatewayclass.yaml | egctl x translate --from gateway-api --to xds -f -
```

特定のxDSリソースタイプのみ出力することもできます（例: routeのみ）。

```sh
cat manifests/httproute-basic.yaml manifests/gateway.yaml manifests/gatewayclass.yaml | egctl x translate --from gateway-api --to xds -t route -f -
```

`--add-missing-resources`オプションを使うと、GatewayClassやGatewayなど足りないリソースを自動補完してくれるため、HTTPRouteだけを渡しても変換できます。

```sh
cat manifests/httproute-basic.yaml | egctl x translate --from gateway-api --to xds --add-missing-resources -f -
```

### Envoy管理画面へのアクセス

`egctl x dashboard`コマンドで、Envoy Proxyの管理画面（admin interface）にブラウザからアクセスできます。

```sh
ENVOY_POD=$(kubectl get pod -n envoy-gateway-system --selector=gateway.envoyproxy.io/owning-gateway-namespace=envoy-gateway-handson,gateway.envoyproxy.io/owning-gateway-name=eg -o jsonpath='{.items[0].metadata.name}')
egctl x dashboard envoy-proxy -n envoy-gateway-system ${ENVOY_POD}
```

```
# 実行結果
http://localhost:19000
```

ブラウザで `http://localhost:19000` にアクセスすると、Envoy Proxyの統計情報やクラスタ情報、設定ダンプなどを確認できます。

### デバッグの流れまとめ

ルーティングがうまくいかない場合は、以下の順番でデバッグすると効率的です。

1. `egctl x status all -A` でリソースのステータスを確認（AcceptedやProgrammedがTrueか）
2. `egctl config envoy-proxy route` で意図したルーティング設定がProxyに反映されているか確認
3. `egctl x translate` でマニフェストからxDSへの変換結果を確認（設定ミスの発見に有用）
4. `egctl x dashboard` でEnvoy管理画面から統計やクラスタ状態を確認

## まとめ

本chapterでは、以下のEnvoy Gatewayの機能を体験しました。

- **基本的なHTTPルーティング**: Gateway APIのHTTPRouteを使ったシンプルなルーティング
- **パスベースルーティング**: URLパスに基づく振り分け
- **ヘッダーベースルーティング**: リクエストヘッダーの値に基づく振り分け(カナリアリリース等)
- **重み付けルーティング**: トラフィックを割合で分散(段階的リリース等)
- **Backendリソース**: Envoy Gateway固有の機能で、外部FQDNへの直接ルーティング
- **BackendTrafficPolicy**: ヘルスチェックによるバックエンドの自動除外

Envoy Gatewayは、Gateway APIに準拠しつつもBackendやBackendTrafficPolicyなどの拡張リソースによって、より柔軟なトラフィック管理を実現しています。Istioのようなサービスメッシュと比べて導入がシンプルであるため、まずはAPI Gatewayとしてトラフィック管理を始めたい場合に適した選択肢です。

## クリーンアップ

ハンズオンで作成したリソースを削除します。

```sh
kubectl delete -f manifests/backend-traffic-policy.yaml --ignore-not-found=true
kubectl delete -f manifests/httproute-basic.yaml --ignore-not-found=true
kubectl delete -f manifests/gateway.yaml
kubectl delete -f manifests/gatewayclass.yaml
kubectl delete -f manifests/app.yaml
```

Envoy Gatewayをアンインストールします。

```sh
helm uninstall eg -n envoy-gateway-system
kubectl delete namespace envoy-gateway-system
```
