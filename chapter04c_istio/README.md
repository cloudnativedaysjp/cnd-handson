# Istio
本chapterではサービスメッシュを実現するためのソフトウェアであるIstioを用いて、メッシュ内のトラフィック管理、可視化、およびセキュリティの担保をどのように実現するのか体験します。

## 概要

## セットアップ
### Istioインストール
helmfileを使用してIstio componentsをインストールします。
```sh
helmfile apply -f helm/helmfile.d/istio.yaml
```

インストールされるcomponentsは下記の通りです。

```sh
NAME                           TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                                 AGE
service/istiod                 ClusterIP   10.96.123.76   <none>        15010/TCP,15012/TCP,443/TCP,15014/TCP   12m
service/istio-ingressgateway   ClusterIP   10.96.109.97   <none>        15021/TCP,80/TCP                        12m

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/istiod                 1/1     1            1           12m
deployment.apps/istio-ingressgateway   1/1     1            1           12m

NAME                                                   MODE     AGE
peerauthentication.security.istio.io/mtls-strict-all   STRICT   12m
```

- istiod: Pilot・Citadel・Galleyの3つのコンポーネントから構成されたIstio control plane
- istio-ingressgateway: Istio mesh内アプリケーションのIngressトラフィックを管理
- peerauthentication: Istioのcustom resourceでenvoy proxy間の通信方法を設定。本設定では、mTLS通信を必須としています。

### アプリケーションdeploy
Envoy sidecar proxyをアプリケーションpodに自動注入するようIstioに指示するために、deploy先のKubernetes namespaceにラベルを追加します。
```sh
kubectl label namespace default istio-injection=enabled
```

アプリケーションをdeployします(`chapter01.5_demo-deploy`でdeploy済みの場合はスキップ。)
```sh
kubectl apply -f ../chapter01.5_demo-deploy/manifest/
```

`chapter01.5_demo-deploy`ですでにアプリケーションをdeployをしている場合はアプリケーションを再起動してpodにenvoy sidecar proxyが追加されるようにします。
```sh
kubectl rollout restart deployment/handson-blue
```

アプリケーションdeploy完了後のKubernetes resourceは下記の通りです。Podが`Running`状態になった後に、アプリケーションpod内でcontainerが2つ動作していることを確認してください。
```sh
kubectl get pod -l app=handson

# 出力例
NAME                            READY   STATUS    RESTARTS   AGE
handson-blue-56c99b9687-ndpjd   2/2     Running   0          15m
```
```sh
kubectl get service -l app=handson

# 出力例
NAME      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
handson   ClusterIP   10.96.251.225   <none>        8080/TCP   36m
```

アプリケーションが正しく起動しているか確認をするために疎通確認をします。現時点ではKubernetes cluster外からはアクセス出来ないため、アプリケーションのKubernetes serviceをport-forwardしてホスト側から疎通確認をします。

- port forward
```sh
kubectl port-forward service/handson 18080:8080 >/dev/null &
```

- 疎通確認
```sh
curl -i http://127.0.0.1:18080/
```
HTTP status code 200と、およびHTMLが無事出力されたら疎通確認完了です。 Port forwaradを終了してください。
```sh
jobs

# 出力例
[1]  + running    kubectl port-forward svc/handson 18080 > /dev/null

# `kubectl port-forward`を実行しているjobを削除。
kill %1
```

アプリケーションの疎通確認ができたので、次は外部(インターネット)からアクセスできるようにします。

まずはIstio mesh外からのアクセスをIstio mesh内のアプリケーションにルーティングできるようするためにIstio gateway/virtual serviceを作成します。
```sh
kubectl apply -f networking/gateway.yaml
kubectl apply -f networking/simple-routing.yaml
```

次に外部(インターネット)からのアクセスを先ほど作成したIstio gatewayにルーティングするためにingress resourceを作成します。
```sh
kubectl apply -f ingress/app-ingress.yaml
```

しばらくすると、ingress resourceにIPが付与されます。
```sh
kubectl -n istio-system get ingress

# 出力例
NAME           CLASS   HOSTS             ADDRESS        PORTS   AGE
app-by-nginx   nginx   app.example.com   10.96.88.164   80      81s
```

これで外部からアクセス出来る準備ができました。ブラウザから`http://app.exmaple.com`にアクセスしてアプリケーションが表示されることを確認してください。

![image](./imgs/app-simple.png)


## サービスメッシュ可視化のためのダッシュボードdeploy
Istioサービスメッシュ内のトラフィックを可視化するために、[Kiali](https://kiali.io/)をインストールします。KialiはIstioサービスメッシュ用のコンソールであり、Kialiが提供するダッシュボードから、サービスメッシュの構造の確認、トラフィックフローの監視、および、サービスメッシュ設定の確認、変更をすることが可能です。

Kialiはトポロジーグラフ、メトリクス等の表示のためにPrometheusを必要とします。Prometheusがまだインストールされていない場合は、下記コマンドを実行してインストールしてください。

Prometheusをインストール(インストール済みの場合はスキップ)します。
```sh
helmfile sync -f ../chapter02_prometheus/helmfile.yaml
```

helmfileを使ってKialiをインストールします。
```sh
helmfile apply -f helm/helmfiles.d/kiali.yaml
```

外部(インターネット)からKialiにアクセスできるようにするためにIngress resourceを作成します。
```sh
kubectl apply -f ingress/kiali-ingress.yaml
```

ブラウザから`http://kiali.example.com`にアクセスをしてKiali dashboardが表示されることを確認してください。

![image](./imgs/kiali-overview.png)

## クリーンアップ
