# Istio Amebient Mesh
本chapterではIstio ambient meshを使用して、サービスメッシュ内のトラフィック管理、可視化をどのように実現するのか体験します。

## 目次
- [概要](#概要)
- [セットアップ](#セットアップ)
- [l4アクセス管理](#l4アクセス管理)
- [l7アクセス管理](#l7アクセス管理)
- [まとめ](#まとめ)
- [最終クリーンアップ](#最終クリーンアップ)

## 概要
### Istio ambient meshとは
2023年2月に[main branchにマージ](https://github.com/istio/istio/pull/43422)された、サイドカーを使用しない新しいIstioデータプレーンモードです。従来のサイドカーモードのIstioは多くの本番運用実績がありますが、データプレーンとアプリケーションの分離ができず、結果下記のような課題があげられています。

- データプレーンはサイドカーとしてアプリケーションpodに注入されるため、Istioデータプレーンのインストール、アップグレード時はpodの再起動が必要になり、アプリケーションワークロードを阻害してしまう
- データプレーンが提供する機能の選択ができないため、一部の機能(mTLS実装のみ等)しか使用しないワークロードにとっては不要なリソースをpodに確保する必要があり、全体のリソースを効率的に使用できなくなる
- HTTP準拠でないアプリケーション実装をしている場合、解析エラーや、誤ったL7プロトコルの解釈を引き起こす可能性がある

Istio ambient meshはこれらの問題を解決する目的で、Google, Solo.ioによって開発が始まりました。

> [!IMPORTANT]
>  Istio ambient meshは2023年11月末時点ではαステータスです。本番環境への導入は控え、検証用途でのみ使用してください。

### Istio ambient mesh構成
L4、L7機能の全てを管理しているサイドカーモードにおけるデータプレーンと異なり、Istio ambientモードではデータプレーンの機能を2つの層に分けて管理をします。

- Secure overlay layer
![image](./image/secure-overlay-layer.png)

(出展元: https://istio.io/v1.16/blog/2022/introducing-ambient-mesh/)

メッシュ内ワークロード内のセキュアな通信の確立を行う層で、[ztunnel](https://github.com/istio/ztunnel)というコンポーネントによって管理されます。Ztunnelの主な役割は1)通信暗号のためのmTLS確立、2)L4レベルの認可、3)TCPメトリクス、ログ収集です。

ZtunnelはKubernetesクラスタ上でDaemonSetとしてデプロイされます。サイドカーモードでは、envoyが各pod内で通信のproxyをしますが、ambientモードではztunnelがメッシュ内のワークロードをnode単位でproxyします。また、node間通信(もう少し厳密に言うと、メッシュ内のサービス間通信)は、Istio 1.16リリースで公開されたHTTP/2のCONNECTメソッドをベースにした[HBONE](https://istio.io/latest/news/releases/1.16.x/announcing-1.16/#hbone-for-sidecars-and-ingress-experimental)(HTTP-Based Overlay Network Environment)というトンネリングを用いたmTLS接続によって行われます。

- waypoint proxy layer
![image](./image/waypoint-proxy-layer.png)

(出展元: https://istio.io/v1.16/blog/2022/introducing-ambient-mesh/)

1)HTTPプロトコル、2)L7レベルの認可、3)HTTPメトリクス、ログ収集等のL7の管理をする層です。Waypoint proxyの実態はenvoyイメージを使用した[Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)のGatewayリソースが作成、管理するpodです。Ztunnelによるsecure overlay layer作成後にKubernetes namespaceごとにwaypoint proxyを作成することで、Istioが提供するL7機能を使用することができます。また、waypoint proxyはワークロード、service account単位でも作成することができます。Waypoint proxyが作成されると、ztunnelによって作成されたsecure overlay layerはトラフィックをそのwaypoint proxyにルーティングすることでL7機能が使えるようになります。

## セットアップ
> [!NOTE]
>
> Istio ambientではCNIとしてCiliumを使用することが現在できません。[chapter01_cluster-create](../chapter01_cluster-create/)はCNIとしてCiliumを使用しているため、本chapter用に新たにKubernetes clusterを作成します。

### Kubernetes cluster作成
```sh
kind create cluster --config kind/config.yaml
```

Kubernetes cluster作成後、現在のKubernetes contextが`kind-istio-ambient`であることを確認してください。
```sh
kubectl config current-context
```
```sh
# 結果表示
kind-istio-ambient
```
もし、結果が`kind-kind`になっている場合は、contextを変更してください(`kind-istio-ambient`の場合はスキップしてください)。
```sh
kubectl config use-context kind-istio-ambient
```

現在のnodeを確認してください。
```sh
kubectl get nodes
```
```sh
# 実行結果
NAME                          STATUS   ROLES           AGE   VERSION
istio-ambient-control-plane   Ready    control-plane   57m   v1.27.3
istio-ambient-worker          Ready    <none>          56m   v1.27.3
```

### インストール
Istio ambientコンポーネントと併せて、Kiali, Prometheusをインストールします。PrometheusはKialiでグラフを表示するために必要となります。

> [!NOTE]
>
> KialiはIstioサービスメッシュ用のコンソールであり、Kialiが提供するダッシュボードから、サービスメッシュの構造の確認、トラフィックフローの監視、および、サービスメッシュ設定の確認、変更をすることが可能です。本chapterでは説明は省略していますので、詳細は[こちら](https://kiali.io)をご確認ください。

```sh
helmfile sync -f helm/helmfile.yaml
```

作成されるリソースは下記のとおりです(Prometheusコンポーネントは省略しています)。
```sh
kubectl get services,daemonsets,deployments -n istio-system
```
```sh
# 実行結果
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                 AGE
service/istiod   ClusterIP   10.96.130.209   <none>        15010/TCP,15012/TCP,443/TCP,15014/TCP   105s
service/kiali    NodePort    10.96.31.119    <none>        28080:30811/TCP                         51s

NAME                            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/istio-cni-node   2         2         2       2            2           kubernetes.io/os=linux   49s
daemonset.apps/ztunnel          2         2         2       2            2           <none>                   49s

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/istiod   1/1     1            1           105s
deployment.apps/kiali    1/1     1            1           51s
```

### アプリケーションのデプロイ
```sh
kubectl apply -f ../chapter01_cluster-create/manifest/app/serviceaccount.yaml -l color=blue
kubectl apply -f ../chapter01_cluster-create/manifest/app/deployment.yaml -l color=blue
kubectl apply -f ../chapter01_cluster-create/manifest/app/service.yaml
```
作成されるリソースは下記のとおりです。
```sh
kubectl get services,deployments -l app=handson
```
```sh
# 実行結果
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/handson   ClusterIP   10.96.230.195   <none>        8080/TCP   2m16s

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/handson-blue   1/1     1            1           2m16s
```

アプリケーションpodがambient meshの一部になるように、デプロイ先のKubernetes namespaceにラベルを追加します。
```sh
kubectl label namespace default istio.io/dataplane-mode=ambient
```
ラベルが追加されたことを確認してください。
```sh
kubectl get namespace default --show-labels
```
```sh
# 実行結果
NAME      STATUS   AGE     LABELS
default   Active   8m41s   istio.io/dataplane-mode=ambient,kubernetes.io/metadata.name=default
```

Ambient mesh内でアプリケーションが正しく起動しているかを確認をするために疎通確認をします。Kubernetes cluster外からはアクセス出来ないため、handsonアプリケーションのKubernetes serviceをポートフォワードしてホスト側から疎通確認をします。

```sh
kubectl port-forward service/handson 8081:8080 >/dev/null &
```

ホストから疎通確認をします。
```sh
curl -I http://127.0.0.1:8081/
```
HTTP status code 200が返却されれば疎通確認完了です。5XXが返却された場合は、`handson-blue` ワークロードを再起動して再度疎通確認を行ってください。

(HTTP status codeが5XXの時のみ実施。)
```sh
kubectl rollout restart deploy/handson-blue
```

疎通確認完了後、Port forwardのjobを停止してください。
```sh
jobs
```
```sh
# 実行結果
[1]+  Running  kubectl port-forward service/handson 8081:8080 > /dev/null &
```

`kubectl port-forward`を実行しているjobを停止。
```sh
kill %1
```

### メッシュの可視化
Kialiを用いてIstioサービスメッシュ内のトラフィックを見てみましょう。Kialiは[インストール](#インストール)でインストール済みなので、外部からアクセスできるようにするため、Kiali serviceのnode portを32766に変更します(KindでKubernetes clusterを作成する際に、host port 28080をcontainer port 32766にマッピングする設定をしているためです)。

```sh
kubectl patch service kiali -n istio-system \
--patch '{"spec": { "type": "NodePort", "ports": [{ "nodePort": 32766, "port": 28080 }]}}'
```

Kiali servcieのnode portが期待通りに変更されたか確認します。
```sh
kubectl get service kiali -n istio-system
```
```sh
# 実行結果
NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)           AGE
kiali   NodePort   10.96.140.207   <none>        28080:32766/TCP   30m
```

> [!NOTE]
>
> KialiのHelm chartではnode portを指定することができないため、このようなアドホックな設定にしています。実ケースでKialiを使用する場合はingressリソース、loadBalancerタイプのKubernetes service等を用いてください。

ブラウザから<http://kiali-ambient.example.com:28080>にアクセスをしてKialiダッシュボードが表示されることを確認してください。

![image](./image/kiali-overview.png)

## L4アクセス管理
Ztunnelによって管理されるL4レベルのトラフィックに対し、Istio Authorization Policyを作成してアクセス管理を実装します。Istio ambient mesh内において、あるワークロードに対して、特定のワークロードからのL4レベルでのアクセス制御をしたい時がユースケースとして挙げられます。本ケースでは、`handson-blue`ワークロードが待ち構えているport 8080へアクセスするワークロードを2つ用意し、ひとつからは許可を、もうひとつからは拒否をするケースを想定します。

[セットアップ](#セットアップ)が完了していることを前提とします。

### Kialiグラフ設定
TCPトラフィックの状態を確認するために、TOP画面左のサイドメニューの`Graph`をクリックし、下記のとおり設定をしてください。
- `Namespace`の`default`にチェック

![image](./image/kiali-graph-namespace.png)

- `Traffic`の`Tcp`のみにチェック

![image](./image/kiali-graph-traffic-tcp.png)

- `Versioned app graph`から`Workload graph`に変更

![image](./image/kiali-graph-workload.png)

- グラフ更新期間を`Every 1m`から`Every 10s`に変更

![image](./image/kiali-graph-refresh-interval.png)

### 追加アプリケーションのデプロイ
`handson-blue`ワークロードにアクセスする追加のワークロード2つをデプロイします。
```sh
kubectl apply -f app/curl-allow.yaml,app/curl-deny.yaml
```

作成されるリソースは下記の通りです。
```sh
kubectl get pods -l content=layer4-authz
```
```sh
# 実行結果
NAME         READY   STATUS    RESTARTS   AGE
curl-allow   1/1     Running   0          46s
curl-deny    1/1     Running   0          46s
```

それでは双方のpodから`handson-blue` ワークロードに対してリクエストをします。
```sh
while :; do
kubectl exec curl-allow -- /bin/sh -c "echo -n 'curl-allow: ';curl -s -o /dev/null handson:8080 -w '%{http_code}\n'";
kubectl exec curl-deny -- /bin/sh -c "echo -n 'curl-deny:  ';curl -s -o /dev/null handson:8080 -w '%{http_code}\n'";
echo ----------------;sleep 1;
done
```

双方のワークロードからのリクエストが成功していることが分かります。
```sh
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

Kiali dashboardからも確認してみましょう。リクエストを流した状態でブラウザから<http://kiali-ambient.example.com:28080>にアクセスをしてください。`curl-allow`, `curl-deny` podのワークロードが`handson-blue`ワークロードにアクセス出来ていることが確認できます(紺色の矢印はTCP通信を表しています)。グラフが表示されない場合は、Kialiダッシュボード右上の青い`Refresh`ボタンを押して状態を更新してください。

![image](./image/kiali-L4-authz-autholizationpolicy-notapplied.png)

確認ができたら、リクエストを一旦停止してください。

### Istio Authorization Policyの適用
それでは、Istio Authorization Policyを作成して、`curl-deny` ワークロードからのport 8080宛のリクエストを拒否する設定を追加します。
```sh
kubectl apply -f networking/L4-authorization-policy.yaml
```

作成されるリソースは下記の通りです。
```sh
kubectl get authorizationpolicies -l content=layer4-authz
```
```sh
# 実行結果
NAME           AGE
layer4-authz   20s
```

再度リクエストをします。
```sh
while :; do
kubectl exec curl-allow -- /bin/sh -c "echo -n 'curl-allow: ';curl -s -o /dev/null -w '%{http_code}\n' handson:8080";
kubectl exec curl-deny -- /bin/sh -c "echo -n 'curl-deny:  ';curl -s -o /dev/null -w '%{http_code}\n' handson:8080";
echo ----------------;sleep 1;
done
```

しばらくすると、`curl-deny` podからのリクエストは拒否されるようになります。
```sh
# 出力結果例
curl-allow: 200
curl-deny:  200
----------------
curl-allow: 200
curl-deny:  200
----------------
curl-allow: 200
curl-deny:  000
command terminated with exit code 56
----------------
curl-allow: 200
curl-deny:  000
command terminated with exit code 56
----------------
curl-allow: 200
curl-deny:  000
command terminated with exit code 56
----------------
.
.
.
```
Http code 000はレスポンスが何もなかったという意味で、`command terminated with exit code 56`はcurlがデータを何も受け取らなかった(コネクションがリセットされた)ということを意味しています。(参考: [curl man page/"Exit Codes"の56](https://curl.se/docs/manpage.html))。

改めてKiali dashboardから確認してみましょう。ブラウザから<http://kiali-ambient.example.com:28080>にアクセスをしてください。しばらくすると、`curl-allow` podからのリクエストのみグラフに表示されるようになります(グラフに変化が見られない場合は、Kialiダッシュボード右上の青い`Refresh`ボタンを押して状態を更新してください)。これは`curl-deny` podからのport 8080のリクエストをztunnelがAuthorization Poliyの設定に基づいて`handson-blue`ワークロードへのproxyを拒否しているためです。

![image](./image/kiali-L4-authz-autholizationpolicy-applied.png)

リクエストを停止し、次は`curl-deny` podのみからリクエストをしてztunnelのログを見てみましょう。
```sh
for _ in $(seq 1 5); do
kubectl exec curl-deny -- /bin/sh -c "echo -n 'curl-deny:  ';curl -s -o /dev/null handson:8080 -w '%{http_code}\n'";
echo ----------------;sleep 1;
done
```

```sh
# 出力結果
curl-deny:  000
command terminated with exit code 56
----------------
curl-deny:  000
command terminated with exit code 56
----------------
curl-deny:  000
command terminated with exit code 56
----------------
.
.
.
```

Ztunnelのログを見る前に、各podのIPを確認します。
```sh
kubectl get pods -o=custom-columns='Name:.metadata.name, IP:.status.podIP'
```
```sh
# 実行結果
Name                           IP
curl-allow                    10.244.1.13
curl-deny                     10.244.1.14
handson-blue-d8476dfd-fft7j   10.244.1.5
```

それではztunnelのlogを確認します。
```sh
ZTUNNEL_POD=$(kubectl get pod -n istio-system -l app=ztunnel --field-selector=spec.nodeName=istio-ambient-worker -o=jsonpath={.items..metadata.name})
kubectl logs "$ZTUNNEL_POD" -n istio-system --tail 10
```
```sh
# 実行結果(1行が長いためtimestampは表示は省略しています)
WARN outbound{id=a0d26a1850f57eba5760b9c2d2b25163}: ztunnel::proxy::outbound: failed dur=124.75¬µs err=http status: 401 Unauthorized
INFO outbound{id=bccd848fbc0077a257d642a254c4e0b9}: ztunnel::proxy::outbound: proxying to 10.244.1.5:8080 using node local fast path
INFO outbound{id=bccd848fbc0077a257d642a254c4e0b9}: ztunnel::proxy::outbound: RBAC rejected conn=10.244.1.14(spiffe://cluster.local/ns/default/sa/curl-deny)->10.244.1.5:8080
WARN outbound{id=bccd848fbc0077a257d642a254c4e0b9}: ztunnel::proxy::outbound: failed dur=146.917¬µs err=http status: 401 Unauthorized
INFO outbound{id=1cbfb371a22e54d86493a16d7ab89636}: ztunnel::proxy::outbound: proxying to 10.244.1.5:8080 using node local fast path
INFO outbound{id=1cbfb371a22e54d86493a16d7ab89636}: ztunnel::proxy::outbound: RBAC rejected conn=10.244.1.14(spiffe://cluster.local/ns/default/sa/curl-deny)->10.244.1.5:8080
WARN outbound{id=1cbfb371a22e54d86493a16d7ab89636}: ztunnel::proxy::outbound: failed dur=118.375¬µs err=http status: 401 Unauthorized
.
.
.
```

ログの2行目を見ると、ztunnelは`curl-deny` pod(IP: 10.244.1.14)からのリクエストを`handson-blue`pod(IP: 10.244.1.5)にproxyしようしていますが(`using node local fast path`は同node内通信という意味です)、次の行では`curl-deny` podから`handson-blue` podへSPIFFEを用いたアクセスはRBAC(先に設定したIstio Authorization Policy)によって拒否され、結果401が返却されていることが分かります。

> [!NOTE]
>
> SPIFFEはCNCFのgratuatedプロジェクトで、アプリケーションサービス間の通信を識別し、保護するためのフレームワークと標準セットを定義しています。本chapterでは説明は省略していますので、詳細は[こちら](https://spiffe.io/docs/latest/spiffe-about/overview/)をご確認ください。

ztunnelが管理するIstio ambient mesh内のL4レベルのトラフィックにおいて、Istio Authorization Policyを使用してアクセス管理を実装しました。Istioの機能を使うことで、アプリケーション側にロジックを追加することなくL4レベルのアクセス管理を実現することができます。

### クリーンアップ
```sh
kubectl delete -f networking/L4-authorization-policy.yaml
kubectl delete -f app/curl-allow.yaml,app/curl-deny.yaml
```

## L7アクセス管理
waypoint proxyによって管理されるL7レベルのトラフィックに対し、Istio Authorization Policyを作成してアクセス管理を実装します。Istio ambient mesh内において、あるワークロードに対して、特定のワークロードからのL7レベルでのアクセス制御をしたい時がユースケースとして挙げられます。本ケースでは`handson-blue`ワークロードにアクセスをするワークロードを1つ用意し、GETメソッドのみ許可(削除、更新系のメソッドは拒否)をするケースを想定します。

[セットアップ](#セットアップ)が完了していることを前提とします。

### Kialiグラフ設定
HTTPトラフィックの状態を確認するために、TOP画面左のサイドメニューのGraphをクリックし、下記のとおり設定してください(設定済みの項目はスキップしてください)。
- `Namespace`の`default`にチェック

![image](./image/kiali-graph-namespace.png)

- `Traffic`の`Http`のみにチェック

![image](./image/kiali-graph-traffic-http.png)

- `Versioned app graph`から`Workload graph`に変更

![image](./image/kiali-graph-workload.png)

- グラフ更新期間を`Every 1m`から`Every 10s`に変更

![image](./image/kiali-graph-refresh-interval.png)

### Waypoint proxyのデプロイ
Waypoint proxyを有効にするにはKubernetes Gateway APIの`gateway`リソースが必要になるため、まずはKubernetes Gateway CRDをインストールします。

```sh
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

> [!NOTE]
>
> Kubernetes Gateway APIは[SIG-Network](https://github.com/kubernetes/community/tree/master/sig-network)コミニティによって開発が行われている、Kubernetesサービスを外部公開するために用いられる新しいAPIリソースです。本chapterでは説明は省略していますので、詳細は[こちら](https://gateway-api.sigs.k8s.io/)をご確認ください。

Kubernetes Gateway APIの`gateway`リソースを作成して、waypoint proxyを有効にします。
```sh
kubectl apply -f networking/k8s-gateway.yaml
```

作成されるリソースは下記の通りです。
```sh
kubectl get services,pods,gateways -l app.kubernetes.io/component=waypoint-proxy
```
```sh
# 実行結果
NAME                             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)               AGE
service/handson-istio-waypoint   ClusterIP   10.96.134.92   <none>        15021/TCP,15008/TCP   54s

NAME                                         READY   STATUS    RESTARTS   AGE
pod/handson-istio-waypoint-b7bb499c6-jx2zz   1/1     Running   0          54s

NAME                                        CLASS            ADDRESS                                            PROGRAMMED   AGE
gateway.gateway.networking.k8s.io/handson   istio-waypoint   handson-istio-waypoint.default.svc.cluster.local   True         54s
```

### 追加アプリケーションのデプロイ
`handson-blue`ワークロードにアクセスするpodをデプロイします。
```sh
kubectl apply -f app/curl.yaml
```

作成されるリソースは下記の通りです。
```sh
kubectl get pods -l content=layer7-authz
```
```sh
# 実行結果
NAME   READY   STATUS    RESTARTS   AGE
curl   1/1     Running   0          15s
```

それでは、`curl` podから`handson-blue`ワークロードに対してリクエストをします。
```sh
while :; do kubectl exec curl -- curl -s -o /dev/null handson:8080 -w '%{http_code}\n';sleep 1;done
```

リクエストは成功していることを確認してください。
```sh
# 出力結果
200
200
200
.
.
.
```

Kiali dashboardからも確認してみましょう。リクエストを流した状態でブラウザから<http://kiali-ambient.example.com:28080>にアクセスをしてください(グラフに変化が見られない場合は、Kialiダッシュボード右上の青い`Refresh`ボタンを押して状態を更新してください)。`curl` podから`handson-blue`ワークロードにアクセス出来ていることが確認できます。

![image](./image/kiali-L7-authz-autholizationpolicy-notapplied.png)

確認ができたら、リクエストを一旦停止してください。

### Istio Authorization Policyの適用
それでは、Istio Authorization Policyを適用して、curl ワークロードからのGETリクエストのみを許可し、削除、更新系のメソッドを拒否します。
```sh
kubectl apply -f networking/L7-authorization-policy.yaml
```

作成されたリソースは下記の通りです。
```sh
kubectl get authorizationpolicy -l content=layer7-authz
```
```sh
# 実行結果
NAME           AGE
layer7-authz   2m24s
```

まずは確認のためにGETリクエストをします(明示的にGETを指定しています)。
```sh
while :; do kubectl exec curl -- curl -s -X GET -o /dev/null -w '%{http_code}\n' handson:8080;sleep 1;done
```

先ほどと同じく、リクエストが成功していることを確認してください。
```sh
# 実行結果
200
200
200
.
.
.
```

リクエストを一旦停止してください。

それでは、POSTメソッドでリクエストをしてみましょう。`handson-blue`ワークロードにPOSTメソッドは実装されていないので、空データを使用します。
```sh
while :; do kubectl exec curl -- curl -X POST -s -o /dev/null -d '{}' -w '%{http_code}\n' handson:8080;sleep 1;done
```

しばらくすると、403にて拒否されるようになります。
```sh
# 実行結果
200
200
403
403
403
.
.
.
```

改めてKiali dashboardから確認してみましょう。ブラウザから<http://kiali-ambient.example.com:28080>にアクセスをしてください(グラフに変化が見られない場合は、Kialiダッシュボード右上の青い`Refresh`ボタンを押して状態を更新してください)。しばらくすると、`curl` ワークロードからのPOSTリクエストは拒否されていることが確認できます。

![image](./image/kiali-L7-authz-autholizationpolicy-applied.png)

確認ができたらリクエストを停止してください。

ここで、ztunnelとwaypoint proxyがどのような動きをしたのかログで確認してみます。

ログを見る前に、まずは各podのIPを確認します。
```sh
kubectl get pods -o=custom-columns='Name:.metadata.name, IP:.status.podIP'
```
```sh
# 実行結果
Name                                      IP
curl                                     10.244.1.16
handson-blue-d8476dfd-fft7j              10.244.1.5
handson-istio-waypoint-b7bb499c6-m5bsr   10.244.1.15
```

それでは、ztunnelのログを見てみましょう。
```sh
ZTUNNEL_POD=$(kubectl get pod -n istio-system -l app=ztunnel --field-selector=spec.nodeName=istio-ambient-worker -o=jsonpath={.items..metadata.name})
kubectl logs "$ZTUNNEL_POD" -n istio-system --tail 10
```
```sh
# 実行結果 (1行が長いためtimestampは表示は省略しています)
INFO outbound{id=7d01633a36b0d76771ce64a74ccaef8a}: ztunnel::proxy::outbound: proxy to 10.96.65.222:8080 using HBONE via 10.244.1.15:15008 type ToServerWaypoint
INFO outbound{id=7d01633a36b0d76771ce64a74ccaef8a}: ztunnel::proxy::outbound: complete dur=2.156042ms
INFO outbound{id=61d06ba5d79b338df5907fc3b39dad21}: ztunnel::proxy::outbound: proxy to 10.96.65.222:8080 using HBONE via 10.244.1.15:15008 type ToServerWaypoint
INFO outbound{id=61d06ba5d79b338df5907fc3b39dad21}: ztunnel::proxy::outbound: complete dur=2.03575ms
.
.
.
```
1行目のログを見ると、HBONEトネリングを使用して、waypoint proxy pod(ID: 10.244.1.19)を経由して`handson` Kubernetes service(IP: 10.96.65.222)にアクセスをしていることがわかります。

次は、waypoint proxyのログを確認してみましょう(JSON出力なので、`jq`コマンドがあれば可視性のために併用してください)。
```sh
WAYPOINT_PROXY_POD=$(kubectl get pods -l app.kubernetes.io/component=waypoint-proxy -o=jsonpath={.items..metadata.name})
kubectl logs "$WAYPOINT_PROXY_POD" --tail 5
```
```sh
# 実行結果 (見やすいようにjqで成形しています)。
{
  "downstream_remote_address": "envoy://internal_client_address/",
  "response_code_details": "rbac_access_denied_matched_policy[ns[default]-policy[layer7-authz]-rule[0]]",
  "response_flags": "-",
  "connection_termination_details": null,
  "upstream_transport_failure_reason": null,
  "x_forwarded_for": null,
  "start_time": "2023-11-23T07:15:16.808Z",
  "upstream_service_time": null,
  "upstream_host": null,
  "route_name": null,
  "response_code": 403,
  "bytes_sent": 19,
  "upstream_cluster": "inbound-vip|8080|http|handson.default.svc.cluster.local",
  "requested_server_name": null,
  "duration": 0,
  "upstream_local_address": null,
  "user_agent": "curl/8.4.0",
  "path": "/",
  "authority": "handson:8080",
  "protocol": "HTTP/1.1",
  "method": "POST",
  "bytes_received": 0,
  "request_id": "a6b37887-9406-4ca2-a3a7-1b00fc3621c2",
  "downstream_local_address": "10.96.65.222:8080"
}
.
.
.
```
`upstream_cluster`として`handson` serviceが認識されていますが、先に設定をしたAuthorization PolicyのRBACによってアクセスが拒否され、upstream(`handson-blue` pod)までリクエストが到達していないことが分かります。

確認ができたらリクエストを停止してください。

最後にDELETEメソッドも拒否されるか確認してみましょう。`handson-blue`ワークロードにDELETEメソッドは実装されていないので、dummy IDを削除することとします。
```sh
while :; do kubectl exec curl -- curl -X DELETE -s -o /dev/null -w '%{http_code}\n' handson:8080/id/123;sleep 1;done
```
こちらも、403にて拒否されることを確認してください。
```sh
# 実行結果
403
403
403
.
.
.
```
確認ができたら、リクエストを停止してください。

Waypoint proxyが管理するIstio ambient mesh内のL7レベルのトラフィックにおいて、Istio Authorization Policyを使用してアクセス管理を実装しました。Istioの機能を使うことで、アプリケーション側にロジックを追加することなくL7レベルのアクセス管理を実現することができます。

### クリーンアップ
```sh
kubectl delete -f networking/L7-authorization-policy.yaml,networking/k8s-gateway.yaml
kubectl delete -f app/curl.yaml
```

## まとめ
サイドカーを用いないIstioの新しいデータプレーンであるIstio ambient meshを使用することで、アプリケーションと、データプレーンの分離が可能になります。これにより、データプレーン起因によるアプリケーションワークロードの阻害を防止することができます。さらに、サイドカーを使用せずに、ztunnel, waypoint proxyを用いることにより、L4, L7管理をアプリケーションの必要に応じて実装することができるようになります。2023年11月の段階ではalphaステータスでありますが、Istio ambient meshをぜひ試してみてください。

Istio ambient meshに関するGitHub Issue: https://github.com/istio/istio/labels/area%2Fambient

## 最終クリーンアップ
本chapter用に作成したKubernetes clusterを削除します。
```sh
kind delete cluster --name istio-ambient
```
他のchapterに進む場合は、cluster削除後にKubernetes contextを`kind-kind`に設定してください。
```sh
kubectl config use-context kind-kind
```
現在のKubernetes contextのが`kind-kind`であることを確認してください。
```sh
kubectl config current-context
```
```sh
# 実行結果
kind-kind
```
