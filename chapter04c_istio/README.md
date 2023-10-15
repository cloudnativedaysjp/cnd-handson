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

## クリーンアップ