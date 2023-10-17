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

## サービスメッシュの可視化
Istioサービスメッシュ内のトラフィックを可視化するために、[Kiali](https://kiali.io/)をインストールします。KialiはIstioサービスメッシュ用のコンソールであり、Kialiが提供するダッシュボードから、サービスメッシュの構造の確認、トラフィックフローの監視、および、サービスメッシュ設定の確認、変更をすることが可能です。

Kialiはトポロジーグラフ、メトリクス等の表示のためにPrometheusを必要とします。Prometheusがまだインストールされていない場合は、下記コマンドを実行してインストールしてください。

Prometheusインストール(インストール済みの場合はスキップ)
```sh
helmfile sync -f ../chapter02_prometheus/helmfile.yaml
```

helmfileを使ってKialiをインストールします。
```sh
helmfile apply -f helm/helmfiles.d/kiali.yaml
```

外部からKialiにアクセスできるようにするためにIngressを設定します。
```sh
kubectl apply -f ingress/kiali-ingress.yaml
```

ブラウザから`http://kiali.example.com`にアクセスをしてください。

![image](./imgs/kiali-overview.png)

## クリーンアップ
