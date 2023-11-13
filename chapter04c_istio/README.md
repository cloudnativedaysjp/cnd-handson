# Istio
本chapterではIstioを用いて、サービスメッシュ内のトラフィック管理、可視化をどのように実現するのか体験します。

## 目次
- [概要](#概要)
- [セットアップ](#セットアップ)
- [加重ルーティング](#加重ルーティング)
- [L4アクセス管理](#l4アクセス管理)
- [L7アクセス管理](#l7アクセス管理)
- [まとめ](#まとめ)
- [クリーンアップ](#クリーンアップ)

## 概要
### Istioとは
Istioはサービスメッシュを実現するためのオープンソースのソフトウェアです。Google, IBM, Lyftによって2017年に開発が開始されましたが、現在多くのコントリビューターによって開発が進めらているCNCFのgraduatedプロジェクトです。Istioを使用することで、アプリケーションにほとんど、または全く変更を加えることなく、マイクロサービス構成のアプリケーションにサービスメッシュを追加することが可能です。

Istioが提供する主な機能は下記のとおりです。

- TLS暗号化によるサービス間通信のセキュリティ確保、強力なアイデンティティベースの認証と承認
- HTTP、gRPC、WebSocket、およびTCPトラフィックの自動負荷分散
- 細かなルーティングルール、リトライ、フェイルオーバー、およびフォールトインジェクションによるトラフィック管理
- アクセス制御、レート制限、クォータのサポートを提供するプラガブルなポリシーレイヤーとAPI
- Istioサービスメッシュへの/からの出入口を含むすべてのトラフィックの自動メトリクス、ログ、トレース

### サービスメッシュとは
サービスメッシュとは、サービス間通信を処理するための専用インフラストラクチャレイヤーです。これにより、透過的に観測性、トラフィック管理、セキュリティなどの機能をアプリケーションに組み込むことなく利用することが可能です。特にcloud nativeアプリケーションにおいてはKubernetesのようなオーケストレーターによって動的にワークロードがスケジューリングされるため、サービス間通信が複雑になります。この管理をアプリケーションではなくサービスメッシュが行うことにより、アプリケーションの管理、運用を容易にすることができます。

### Istioアーキテクチャ
![image](./imgs/istio-architecture.png)

(出展元: https://istio.io/latest/docs/ops/deployment/architecture/)

Istioサービスメッシュは大きく2つのコンポーネントで構成されます。
- コントロールプレーン: Istiodというシングルバイナリで、トラフィックをproxyするための設定、および管理をします。。このシングルバイナリはPilot, Citadel, Galleyと呼ばれるコンポーネントで構成されており、各コンポーネントの主な機能は下記のとおりです。

  - Pilot: ランタイム時のproxy設定
  - Citadel: メッシュ内で使用される証明書の発行、更新
  - Galley: メッシュ内設定の検証、取り込み、集約、変換、配布

- データプレーン: サイドカーとしてdeployされるenvoyベースのプロキシです。マイクロサービス間のすべてのネットワーク通信を制御し、メッシュトラフィック全体に関するテレメトリの収集を行います。

## セットアップ
### Istioのインストール
```sh
helmfile apply -f helm/helmfile.d/istio.yaml
```

作成されるリソースは下記のとおりです。
```sh
kubectl -n istio-system get service,deployment

# 出力結果例
NAME                           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                 AGE
service/istio-ingressgateway   ClusterIP   10.96.12.35     <none>        15021/TCP,80/TCP                        73s
service/istiod                 ClusterIP   10.96.112.206   <none>        15010/TCP,15012/TCP,443/TCP,15014/TCP   93s

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/istio-ingressgateway   1/1     1            1           73s
deployment.apps/istiod                 1/1     1            1           93s
```

`istiod`がコントロールプレーンです。データプレーンはアプリケーションpodにサイドカーとして注入されるため、この段階ではまだ確認をすることはできません。

### アプリケーションのdeploy
Envoy sidecar proxyをアプリケーションpodに自動注入するようIstioに指示するために、deploy先のKubernetes namespaceにラベルを追加します。
```sh
kubectl label namespace default istio-injection=enabled
```
ラベルが追加されたことを確認してください。
```sh
kubectl get namespace default --show-labels

# 出力結果例
NAME      STATUS   AGE   LABELS
default   Active   28m   istio-injection=enabled,kubernetes.io/metadata.name=default
```

アプリケーションをdeployします。`chapter01.5_demo-deploy`でdeploy済みの場合はアプリケーションを再起動してpodにサイドカーとしてenvoy proxyが注入されるようにします。
```sh
# アプリケーションが未deployの場合。
kubectl apply -f ../chapter01.5_demo-deploy/manifest/

# アプリケーションdeploy済みの場合。
kubectl rollout restart deployment/sample-app-blue
```

アプリケーション再起動、またはdeploy完了後のリソースは下記の通りです。Podが`Running`状態になった後に、アプリケーションpod内でcontainerが2つ動作していることを確認してください。
```sh
kubectl get service,pod -l app=sample-app

＃ 出力結果例
NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/sample-app   ClusterIP   10.96.105.254   <none>        8080/TCP   28m

NAME                                   READY   STATUS    RESTARTS   AGE
pod/sample-app-blue-774d676858-4bnhm   2/2     Running   0          13m
```

Envoy proxyがサイドカーとしてアプリケーションpodに注入されているか確認しましょう。
```sh
kubectl get pods -l app=sample-app -o jsonpath={.items..spec..containers..image} | tr -s '[[:space:]]' '\n';echo

# 出力結果
docker.io/istio/proxyv2:1.19.0
argoproj/rollouts-demo:blue
```
`proxyv2`のイメージで動作しているコンテナがデータプレーンです。

では、アプリケーションが正しく起動しているか確認をするために疎通確認をします。現時点ではKubernetes cluster外からはアクセス出来ないため、アプリケーションのKubernetes serviceをポートフォワードしてホスト側から疎通確認をします。

`sample-app` serviceをport forwardします。
```sh
kubectl port-forward service/sample-app 18080:8080 >/dev/null &
```

ホストから疎通確認をします。
```sh
curl -i http://127.0.0.1:18080/
```
HTTP status code 200、およびHTMLが無事出力されたら疎通確認完了です。 Port forwardのjobを停止してしてください。
```sh
jobs

# 出力結果例
[1]  + running    kubectl port-forward svc/sample-app 18080 > /dev/null

# `kubectl port-forward`を実行しているjobを停止。
kill %1
```

### 外部からのアプリケーション疎通
アプリケーションの疎通確認ができたので、次は外部(インターネット)からアクセスできるようにします。

まずはIstioメッシュ外からのアクセスをIstioメッシュ内のアプリケーションにルーティングできるようするためにIstio gateway/virtual serviceを作成します。
```sh
kubectl apply -f networking/gateway.yaml
kubectl apply -f networking/simple-routing.yaml
```

作成されるリソースは下記のとおりです。
```sh
kubectl get gateway,virtualservice

# 出力結果例
NAME                                     AGE
gateway.networking.istio.io/sample-app   3m21s

NAME                                                GATEWAYS         HOSTS                 AGE
virtualservice.networking.istio.io/simple-routing   ["sample-app"]   ["app.example.com"]   61s
```

次に外部(インターネット)からのアクセスを先ほど作成したIstio gatewayにルーティングするためにingressリソースを作成します。
```sh
kubectl apply -f ingress/app-ingress.yaml
```

しばらくすると、ingressリソースにIPが付与されます。
```sh
kubectl -n istio-system get ingress -l app=sample-app

# 出力結果例
NAME           CLASS   HOSTS             ADDRESS        PORTS   AGE
app-by-nginx   nginx   app.example.com   10.96.88.164   80      81s
```

これで外部からアクセス出来る準備ができました。ブラウザから`http://app.exmaple.com`にアクセスしてアプリケーションが表示されることを確認してください。

![image](./imgs/app-simple-routing.png)

### Kialiのdeploy
Istioサービスメッシュ内のトラフィックを可視化するために、[Kiali](https://kiali.io/)をdeployします。KialiはIstioサービスメッシュ用のコンソールであり、Kialiが提供するダッシュボードから、サービスメッシュの構造の確認、トラフィックフローの監視、および、サービスメッシュ設定の確認、変更をすることが可能です。

Kialiはトポロジーグラフ、メトリクス等の表示のためにPrometheusを必要とします。Prometheusがまだインストールされていない場合は、下記コマンドを実行してインストールしてください。すでにインストール済みの場合は、スキップをしてKialiをインストールしてください。

```sh
# Prometheusがまだインストールされていない場合のみ。
helmfile sync -f ../chapter02_prometheus/helmfile.yaml
```

helmfileを使ってKialiをインストールします。
```sh
helmfile apply -f helm/helmfile.d/kiali.yaml
```

作成されるリソースは下記の通りです。
```sh
kubectl -n istio-system get service,pod -l app=kiali

# 出力結果例
NAME            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)              AGE
service/kiali   ClusterIP   10.96.123.32   <none>        20001/TCP,9090/TCP   36s

NAME                        READY   STATUS    RESTARTS   AGE
pod/kiali-8cf44fffc-h6hkw   1/1     Running   0          36s
```

外部(インターネット)からKialiにアクセスできるようにするためにIngressリソースを作成します。
```sh
kubectl apply -f ingress/kiali-ingress.yaml
```

しばらくすると、ingressリソースにIPが付与されます。
```sh
kubectl -n istio-system get ingress -l app=kiali

# 出力結果例
NAME             CLASS   HOSTS               ADDRESS        PORTS   AGE
kiali-by-nginx   nginx   kiali.example.com   10.96.88.164   80      2m5s
```

ブラウザから`http://kiali.example.com`にアクセスをしてKialiダッシュボードが表示されることを確認してください。

![image](./imgs/kiali-overview.png)

Kialiダッシュボードのグラフ表示の設定を変更します。TOP画面左のサイドメニューの`Graph`をクリックし、画面上部にある表示項目を下記の通り設定してください。
- `Namespace`の`default`にチェック

![image](./imgs/kiali-graph-namespace.png)

- `Versioned app graph`から`Workload graph`に変更

![image](./imgs/kiali-graph-workload.png)

- `Display`項目から`Traffic Distribution`をチェック

![image](./imgs/kiali-graph-traffic-distribution.png)

## 加重ルーティング
Istio Virtual Service/Destination Ruleを用いて加重ルーティングを実装します。旧バージョンから新バージョンへのアプリケーションの段階的な移行がユースケースとして挙げられます。本ケースでは、現在稼働しているアプリケーションとコンテナイメージタグが異なる追加のアプリケーションをdeployし、トラフィックを50%ずつ振り分けて、最終的に新しいアプリケーションに移行するシナリオを想定します。

[セットアップ](#セットアップ)が完了していることを前提とします。

### 追加アプリケーションのdeploy
現在動作中のアプリケーションは下記のとおりです。
```sh
kubectl get pod -l app=sample-app

# 出力結果例
NAME                               READY   STATUS    RESTARTS   AGE
sample-app-blue-58844598d6-4zbzh   2/2     Running   0          31s
```

加重ルーティング実装のための追加アプリケーションをdeployします。
```sh
kubectl apply -f app/sample-app-yellow.yaml
```

2つのアプリケーションが`default`namespace下で起動していることを確認してください。
```sh
kubectl get pod -l app=sample-app

# 出力結果例
NAME                                 READY   STATUS    RESTARTS   AGE
sample-app-blue-5979d657bd-fw6pf     2/2     Running   0          54m
sample-app-yellow-58c8c8d6d6-zkpgd   2/2     Running   0          41s
```

### トラフィック移行
50%ずつ加重ルーティングされるように[アプリケーションのdeploy](#アプリケーションのdeploy)で作成したIstio Virtual Serviceを削除し、新しいメッシュ内ルーティング設定をします。
```sh
kubectl delete -f networking/simple-routing.yaml
kubectl apply -f networking/weight-based-routing.yaml
```

作成されるリソースは下記のとおりです。
```sh
kubectl get virtualservice,destinationrule

# 出力結果例
NAME                                                      GATEWAYS         HOSTS                 AGE
virtualservice.networking.istio.io/weight-based-routing   ["sample-app"]   ["app.example.com"]   29s

NAME                                                       HOST         AGE
destinationrule.networking.istio.io/weight-based-routing   sample-app   29s
```

実際にリクエストを流して、期待した通り50%ずつトラフィックが流れているかKialiで確認してみましょう。ローカル端末から下記コマンドを実行してください。
```sh
while :; do curl -s -o /dev/null -w '%{http_code}\n' http://app.example.com;sleep 1;done
```

しばらくすると、グラフが表示されます(なかなか表示されない場合は、Kialiダッシュボード右上の青い`Refresh`ボタンを押して状態を更新してください)。しばらくすると、トラフィックが凡そ均等にルーティングされていることを確認してください。
![image](./imgs/kiali-graph-weigh-based-routing-50-50.png)

それでは、リクエストを一旦停止し、新しいアプリケーションにトラフィックが100%ルーティングされるように設定を変更します。
```sh
kubectl patch virtualservice weight-based-routing --type merge --patch-file networking/weight-based-routing-patch.yaml
```

再度リクエストを流します。
```sh
while :; do curl -s -o /dev/null -w '%{http_code}\n' http://app.example.com;sleep 1;done
```

しばらくすると、新しいアプリケーションにトラッフィックが100%ルーティングされていることが確認できます(変化が見られない場合は、Kialiダッシュボード右上の青い`Refresh`ボタンを押して状態を更新してください)。
![image](./imgs/kiali-graph-weigh-based-routing-0-100.png)

確認ができたらリクエストは停止してください。

Istio Virtual Service/Destination Ruleを使用して、加重ルーティングを実装しました。Istioの機能を利用することで、アプリケーション側にロジックを追加することなく複数アプリケーション間のトラフィック移行を実現することができます。

### クリーンアップ
```sh
kubectl delete -f app/sample-app-yellow.yaml
kubectl delete -f networking/gateway.yaml,networking/weight-based-routing.yaml
```

## L4アクセス管理
L4レベルのトラフィックに対し、Istio Authorization Policyを作成してアクセス管理を実装します。Istioメッシュ内において、あるワークロードに対して特定のワークロードからのL4レベルでのアクセス制御したい時がユースケースとして挙げられます。本ケースでは、現在稼働しているアプリケーションにアクセスするワークロードを2つ用意し、portレベルでひとつからは許可を、もうひとつからは拒否をするケースを想定します。

[セットアップ](#セットアップ)が完了していることを前提とします。

### 追加アプリケーションdeploy
現在動作中のアプリケーションは下記のとおりです。
```sh
kubectl get pod -l app=sample-app

# 出力結果例
NAME                               READY   STATUS    RESTARTS   AGE
sample-app-blue-58844598d6-4zbzh   2/2     Running   0          64s
```

このアプリケーションにアクセスするワークロードを2つdeployします。
```sh
kubectl apply -f app/curl-allow.yaml,app/curl-deny.yaml
```

作成されるリソースは下記の通りです。
```sh
kubectl get po -l content=layer4-authz

# 出力結果例
NAME         READY   STATUS    RESTARTS   AGE
curl-allow   2/2     Running   0          29s
curl-deny    2/2     Running   0          29s
```

それでは`curl-allow`, `curl-deny`双方のワークロードから`sample-app-blue` ワークロードに対してリクエストをします。
```sh
while :; do
kubectl exec curl-allow -- /bin/sh -c "echo -n 'curl-allow: ';curl -s -o /dev/null -w '%{http_code}\n' sample-app:8080";
kubectl exec curl-deny -- /bin/sh -c "echo -n 'curl-deny:  ';curl -s -o /dev/null -w '%{http_code}\n' sample-app:8080";
echo ----------------;sleep 1;
done
```

双方からのリクエストは成功していることが分かります。
```
# 出力結果
curl-allow: 200
curl-deny:  200
----------------
curl-allow: 200
curl-deny:  200
----------------
curl-allow: 200
curl-deny:  200
----------------
.
.
.
```

Kiali dashboardからも確認してみましょう。リクエストを流した状態でブラウザから`http://kiali.example.com`にアクセスをしてください。`curl-allow`, `curl-deny` 双方のワークロードが`sample-app-blue`ワークロードにアクセス出来ていることが確認できます(グラフが表示されない場合は、Kialiダッシュボード右上の青い`Refresh`ボタンを押して状態を更新してください)。

![image](./imgs/kiali-L4-authz-autholizationpolicy-notapplied.png)

リクエストは一旦停止してください。

### Istio Authorization Policy適用
それでは、Istio Authorization Policyを作成して、`curl-deny` ワークロードからのport 8080宛に対するリクエストを拒否する設定を追加します。
```sh
kubectl apply -f networking/L4-authorization-policy.yaml
```

作成されるリソースは下記の通りです。
```sh
kubectl get authorizationpolicy -l content=layer4-authz

# 出力結果例
NAME           AGE
layer4-authz   27s
```

再度リクエストをします。
```sh
while :; do
kubectl exec curl-allow -- /bin/sh -c "echo -n 'curl-allow: ';curl -s -o /dev/null -w '%{http_code}\n' sample-app:8080";
kubectl exec curl-deny -- /bin/sh -c "echo -n 'curl-deny:  ';curl -s -o /dev/null -w '%{http_code}\n' sample-app:8080";
echo ----------------;sleep 1;
done
```

しばらくすると、`curl-deny` ワークロードからのリクエストは拒否されるようになります。

```
# 出力結果例
curl-allow: 200
curl-deny:  200
----------------
curl-allow: 200
curl-deny:  200
----------------
curl-allow: 200
curl-deny:  403
----------------
curl-allow: 200
curl-deny:  403
----------------
.
.
.
```

改めてKiali dashboardから確認してみましょう。ブラウザから`http://kiali.example.com`にアクセスをしてください。しばらくすると、`curl-allow` ワークロードからのリクエストは許可されている一方で、`curl-deny` ワークロードからのリクエストは拒否されていることが確認できます(変化が見られない場合は、Kialiダッシュボード右上の青い`Refresh`ボタンを押して状態を更新してください)。

![image](./imgs/kiali-L4-authz-autholizationpolicy-applied.png)

確認ができたら、リクエストは停止してください。

Istio Authorization Policyを使用して、Istioメッシュ内のL4レベルのアクセス管理を実装しました。Istioの機能を利用することで、アプリケーション側にロジックを追加することなくL4レベルのアクセス管理を実現することができます。

### クリーンアップ
```sh
kubectl delete -f networking/L4-authorization-policy.yaml
kubectl delete -f app/curl-allow.yaml,app/curl-deny.yaml
```

## L7アクセス管理
Istio Authorization Policyを用いてL7レベルのアクセス管理を実装します。Istioメッシュ内において、あるワークロードに対して特定のワークロードからのL7レベルでのアクセスを制御したい時がユースケースとして挙げられます。本ケースでは現在稼働しているアプリケーションにアクセスをするワークロードを1つ用意し、GETメソッドのみ許可し、それ以外は拒否をするケースを想定します。

[セットアップ](#セットアップ)が完了していることを前提とします。

### 追加アプリケーションdeploy
現在動作中のアプリケーションは下記のとおりです。
```sh
kubectl get pod -l app=sample-app

# 出力結果例
NAME                               READY   STATUS    RESTARTS   AGE
sample-app-blue-58844598d6-4zbzh   2/2     Running   0          7m18s
```

`sample-app-blue`ワークロードにアクセスするワークロードをdeployします。
```sh
kubectl apply -f app/curl.yaml
```

作成されるリソースは下記のとおりです。
```sh
kubectl get po -l content=layer7-authz

# 出力結果例
NAME   READY   STATUS    RESTARTS   AGE
curl   2/2     Running   0          24s
```

それでは、`curl` ワークロードから`sample-app-blue`ワークロードに対してリクエストをします。
```sh
while :; do kubectl exec curl -- curl -s -o /dev/null -w '%{http_code}\n' sample-app:8080;sleep 1;done
```

リクエストは成功していることを確認してください。
```
# 出力結果
200
200
200
.
.
.
```

Kiali dashboardからも確認してみましょう。リクエストを流した状態でブラウザから`http://kiali.example.com`にアクセスをしてください。`curl` ワークロードから`sample-app-blue`ワークロードにアクセス出来ていることが確認できます(なかなか表示されない場合は、Kialiダッシュボード右上の青い`Refresh`ボタンを押して状態を更新してください)。

![image](./imgs/kiali-L7-authz-autholizationpolicy-notapplied.png)

リクエストは一旦停止してください。

### Istio Authorization Policy適用
それでは、Istio Authorization Policyを適用して、`curl` ワークロードからのGETリクエストのみを許可し、それ以外は拒否します。
```sh
kubectl apply -f networking/L7-authorization-policy.yaml
```

作成されたリソースは下記の通りです。
```sh
kubectl get authorizationpolicy -l content=layer7-authz

# 出力結果例
NAME           AGE
layer7-authz   2m24s
```

まずはGETリクエストをします。
```sh
while :; do kubectl exec curl -- curl -s -o /dev/null -w '%{http_code}\n' sample-app:8080;sleep 1;done
```

先ほどと同じくリクエストは成功することを確認してください。
```
# 出力結果
200
200
200
.
.
.
```

リクエストは一旦停止してください。

それでは、POSTメソッドでリクエストをしてみましょう(`sample-app-blue`ワークロードにPOSTメソッドは実装されていないので、空データを使用します)。
```sh
while :; do kubectl exec curl -- curl -X POST -s -o /dev/null -d '{}' -w '%{http_code}\n' sample-app:8080;sleep 1;done
```

しばらくすると、`curl` podからのリクエストは403にて拒否されるようになります。
```
# 出力結果例
200
200
403
403
403
.
.
.
```

改めてKiali dashboardから確認してみましょう。ブラウザから`http://kiali.example.com`にアクセスをしてください。しばらくすると、`curl` ワークロードからのPOSTリクエストは拒否されていることが確認できます(変化が見られない場合は、Kialiダッシュボード右上の青い`Refresh`ボタンを押して状態を更新してください)。

![image](./imgs/kiali-L7-authz-autholizationpolicy-applied.png)

確認ができたらリクエストは停止してください。

Istio Authorization Policyを使用して、Istioメッシュ内のL7レベルのアクセス管理を実装しました。Istioの機能を利用することで、アプリケーション側にロジックを追加することなく、L7レベルのアクセス管理を実現することができます。

### クリーンアップ
```sh
kubectl delete -f networking/L7-authorization-policy.yaml
kubectl delete -f app/curl.yaml
```

## まとめ
サービスメッシュを提供するIstioを使用することで、アプリケーションレイヤーではなくインフラレイヤーでサービス間のトラフィック管理を、またKialiを使用することでサービスメッシュの可視化をすることができます。本chapterではVirtual Service, Destination Ruleを使用したルーティング制御、Authorization Policyを使用した認可処理しか紹介していませんが、Istioには他にも[沢山の機能](https://istio.io/latest/docs/tasks/)がありますので、是非確認してみてください。

## クリーンアップ
Istio, Kialiを削除します。
```sh
helmfile delete -f helm/helmfile.d/
```