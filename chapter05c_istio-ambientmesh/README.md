# Istio Amebient Mesh
本chapterでは[Istio](../chapter04c_istio/) chapterで使用したsidecarを用いない新しいデータプレーンモードであるIstio ambient mesh*を体験します。
<br/><br/>
*現在αステータス(2023年9月)のため、本番環境での使用は控えるようにしてください。

## 概要

## セットアップ
> **Important**
> Istio ambientではCNIとしてciliumを使用することが現在できません。チャプター1でciliumベースのKubernetes clusterを作成している場合は、clusterを先に削除してから本チャプターを進めてください。

### Kubernetes cluster作成
```sh
kind create cluster --config kind/config.yaml
```

## セットアップ
### Istio ambientのインストール
helmfileを使用してインストールをします。
```sh
helmfile apply -f helm/helmfile.d/istio-ambient.yaml
```

作成されるリソースは下記のとおりです。
```sh
kubectl -n istio-system get service,daemonset,deployment

# 出力結果例
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                                 AGE
service/istiod   ClusterIP   10.96.87.196   <none>        15010/TCP,15012/TCP,443/TCP,15014/TCP   92s

NAME                            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/istio-cni-node   2         2         2       2            2           kubernetes.io/os=linux   72s
daemonset.apps/ztunnel          2         2         2       2            2           <none>                   72s

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/istiod   1/1     1            1           92s
```

### アプリケーションのdeploy
アプリケーションpodがambient meshの一部になるように、deploy先のKubernetes名前空間にラベルを追加します。
```sh
kubectl label namespace default istio.io/dataplane-mode=ambient
```

アプリケーションをdeployします。
```sh
kubectl apply -f ../chapter01.5_demo-deploy/manifest/
```

作成されるリソースは下記のとおりです。Istio sidecarモードと違って、envoy proxy containerは注入されないため、アプリケーションpod内のcontainerは1つだけです。
```sh
kubectl get service,pod -l app=sample-app

# 出力結果例
NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/sample-app   ClusterIP   10.96.82.102   <none>        8080/TCP   31s

NAME                                   READY   STATUS    RESTARTS   AGE
pod/sample-app-blue-5b4fcf9fb6-9cbmx   1/1     Running   0          31s
```

アプリケーションが正しく起動しているか確認をするために疎通確認をします。現時点ではKubernetes cluster外からはアクセス出来ないため、アプリケーションのKubernetes serviceをポートフォワードしてホスト側から疎通確認をします。

`sample-app` serviceをport forwardします。
```sh
kubectl port-forward service/sample-app 18080:8080 >/dev/null &
```

ホストから疎通確認をします。
```sh
curl -i http://127.0.0.1:18080/
```
HTTP status code 200、およびHTMLが無事出力されたら疎通確認完了です。もし5XXが返却された場合は、`sample-app` podを削除して、再作成してから再度疎通確認を実施してください。

疎通確認完了後、Port forwardのjobを停止してください。
```sh
jobs

# 出力結果例
[1]  + running    kubectl port-forward svc/sample-app 18080 > /dev/null

# `kubectl port-forward`を実行しているjobを停止。
kill %1
```

## Kialiのdeploy
Istioサービスメッシュ内のトラフィックを可視化するために、[Kiali](https://kiali.io/)をdeployします。KialiはIstioサービスメッシュ用のコンソールであり、Kialiが提供するダッシュボードから、サービスメッシュの構造の確認、トラフィックフローの監視、および、サービスメッシュ設定の確認、変更をすることが可能です。

Kialiはトポロジーグラフ、メトリクス等の表示のためにPrometheusを必要とするため、まずはPrometheusをdeployします。
```sh
helmfile sync -f ../chapter02_prometheus/helmfile.yaml
```

Prometheusのdeploy完了後、helmfileを使ってKialiをインストールします。
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

## L4アクセス管理
ztunnelによって管理されるL4レベルのトラフィックに対し、Istio Authorization Policyを作成してアクセス管理を実装します。Istio ambient mesh内において、あるワークロードに対して、特定のワークロードからのL4レベルでのアクセス制御をしたい時がユースケースとして挙げられます。本ケースでは、`sample-app`ワークロードが待ち構えているport 8080へアクセスするワークロードを2つ用意し、ひとつからは許可を、もうひとつからは拒否をするケースを想定します。

[セットアップ](#セットアップ)が完了していることを前提とします。

### Kialiグラフ設定
TCPトラフィックの状態を確認するために、TOP画面左のサイドメニューのGraphをクリックし、下記のとおり設定をしてください。
- `Namespace`の`default`にチェック

![image](./imgs/kiali-graph-namespace.png)

- `Traffic`の`Tcp`のみにチェック

![image](./imgs/kiali-graph-traffic-tcp.png)

- `Versioned app graph`から`Workload graph`に変更

![image](./imgs/kiali-graph-workload.png)


### 追加アプリケーションdeploy
`sample-app`ワークロードにアクセスする追加のワークロードを2つdeployします。
```sh
kubectl apply -f app/curl-allow.yaml,app/curl-deny.yaml
```

作成されるリソースは下記の通りです。
```sh
kubectl get po -l content=layer4-authz

# 出力結果例
NAME         READY   STATUS    RESTARTS   AGE
curl-allow   1/1     Running   0          46s
curl-deny    1/1     Running   0          46s
```

それでは双方のpodから`sample-app` ワークロードに対してリクエストをします。
```sh
while :; do
kubectl exec curl-allow -- /bin/sh -c "echo -n 'curl-allow: ';curl -s -o /dev/null sample-app:8080 -w '%{http_code}\n'";
kubectl exec curl-deny -- /bin/sh -c "echo -n 'curl-deny:  ';curl -s -o /dev/null sample-app:8080 -w '%{http_code}\n'";
echo ----------------;sleep 1;
done
```

`curl-allow`, `curl-deny` pod双方からのリクエストは成功していることが分かります。
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

Kiali dashboardからも確認してみましょう。リクエストを流した状態でブラウザから`http://kiali.example.com`にアクセスをしてください。`curl-allow`, `curl-deny` podの双方が`sample-app`ワークロードにアクセス出来ていることが確認できます(矢印が紺色なのはTCP通信を表しています)。下記図のようになっていない場合は、ブラウザを数回リロードしてください。

![image](./imgs/kiali-L4-authz-autholizationpolicy-notapplied.png)

ここで`sample-app`ワークロードへのリクエストは一旦停止してください。

### Istio Authorization Policy適用
それでは、Istio Authorization Policyを作成して、`curl-deny` podから`sample-app` serviceへのport 8080宛のリクエストを拒否する設定を追加します。
```sh
kubectl apply -f networking/L4-authorization-policy.yaml
```

作成されるリソースは下記の通りです。
```sh
kubectl get authorizationpolicy -l content=layer4-authz

# 出力結果例
NAME           AGE
layer4-authz   20s
```

`sample-app` ワークロードに対して, `curl-allow`, `curl-deny` podから再度リクエストをします。
```sh
while :; do
kubectl exec curl-allow -- /bin/sh -c "echo -n 'curl-allow: ';curl -s -o /dev/null sample-app:8080 -w '%{http_code}\n'";
kubectl exec curl-deny -- /bin/sh -c "echo -n 'curl-deny:  ';curl -s -o /dev/null sample-app:8080 -w '%{http_code}\n'";
echo ----------------;sleep 1;
done
```

しばらくすると、`curl-deny` podからのリクエストは拒否されるようになります。
```plain
# 出力結果例
curl-allow: 200
curl-deny:  200
----------------
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
Http code`000`はレスポンスが何もなかったという意味で、`command terminated with exit code 56`はcurlがデータを何も受け取らなかった(コネクションがリセットされた)ということを意味しています。(参考: [curl man page/"Exit Codes"の56](https://curl.se/docs/manpage.html))。

改めてKiali dashboardから確認してみましょう。ブラウザから`http://kiali.example.com`にアクセスをしてください。しばらくすると、`curl-allow` podからのリクエストのみグラフに表示されるようになります。これは`curl-deny` podからのport 8080のリクエストをztunnelがAuthorization Poliyの設定に基づいて`sample-app`ワークロードへのproxyを拒否しているためです。

![image](./imgs/kiali-L4-authz-autholizationpolicy-applied.png)

`sample-worload`へのリクエストを停止し、次は`curl-deny` podのみからリクエストをしてztunnelのログを見てみましょう。
```sh
while :; do
kubectl exec curl-deny -- /bin/sh -c "echo -n 'curl-deny:  ';curl -s -o /dev/null sample-app:8080 -w '%{http_code}\n'";
echo ----------------;sleep 1;
done
```

```plain
# 出力結果例
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

10秒ほど経過したらリクエストを停止して、ztunnelのcontainer logを確認します。
```sh
ZTUNNEL_POD=$(kubectl get pod -n istio-system -l app=ztunnel --field-selector=spec.nodeName=istio-ambient-worker -o=jsonpath={.items..metadata.name})

kubectl logs -n istio-system "$ZTUNNEL_POD"
```
```plain
# 出力結果例(1行が長いためtimestampは表示は省略しています)
(前略)
INFO outbound{id=592141ddcfee48d3532f5a1d18716a8a}: ztunnel::proxy::outbound: proxying to 10.244.1.18:8080 using node local fast path
INFO outbound{id=592141ddcfee48d3532f5a1d18716a8a}: ztunnel::proxy::outbound: RBAC rejected conn=10.244.1.20(spiffe://cluster.local/ns/default/sa/curl-deny)->10.244.1.18:8080
WARN outbound{id=592141ddcfee48d3532f5a1d18716a8a}: ztunnel::proxy::outbound: failed dur=169.208¬µs err=http status: 401 Unauthorized
INFO outbound{id=7f77e5fb4e26f7bd07d6a36a57a8e3cf}: ztunnel::proxy::outbound: proxying to 10.244.1.18:8080 using node local fast path
INFO outbound{id=7f77e5fb4e26f7bd07d6a36a57a8e3cf}: ztunnel::proxy::outbound: RBAC rejected conn=10.244.1.20(spiffe://cluster.local/ns/default/sa/curl-deny)->10.244.1.18:8080
WARN outbound{id=7f77e5fb4e26f7bd07d6a36a57a8e3cf}: ztunnel::proxy::outbound: failed dur=165.5¬µs err=http status: 401 Unauthorized
(後略)
```

`curl-deny` pod(IP: 10.244.1.20)から`sample-app` pod(IP: 10.244.1.18)のport 8080へのアクセスはztunnelによって拒否されて、TCPセグメントは`sample-app`に到達していないことが分かります。

ztunnelが管理するIstio ambient mesh内のL4レベルのトラフィックにおいて、Istio Authorization Policyを使用してアクセス管理を実装しました。Istioの機能を使うことで、アプリケーション側にロジックを追加することなくL4レベルのアクセス管理を実現することができます。

### クリーンアップ
```sh
kubectl delete -f networking/L4-authorization-policy.yaml
kubectl delete -f app/curl-allow.yaml,app/curl-deny.yaml
```
