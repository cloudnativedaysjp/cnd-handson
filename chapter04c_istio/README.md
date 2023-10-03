# Istio
本chapterではサービスメッシュを実現するためのソフトウェアであるIstioを用いて、メッシュ内のトラフィック管理、可視化、およびセキュリティの担保をどのように実現するのか体験します。

## 概要

## セットアップ
### Istioインストール
- helmfileを使用してIstioをインストールします。
```sh
helmfile apply -f helm/helmfile.yaml
```

- サンプルアプリケーションをdeployする際に、IstioにEnvoyサイドカープロキシを自動注入するよう指示するために、Kubernetes namespaceにラベルを追加します。
```sh
kubectl label namespace default istio-injection=enabled
```

## クリーンアップ
