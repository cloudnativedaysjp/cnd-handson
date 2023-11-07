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
