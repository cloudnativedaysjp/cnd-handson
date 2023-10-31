# Chapter 05d Service Mesh

Service Meshの機能と聞くと、以下の機能を期待されるかと思います。
それぞれの機能について説明します。

- Ingress
- L7-Aware Traffic Management
- Identity-based Security

## Ingress

[Kubernetes Ingress Support](https://docs.cilium.io/en/stable/network/servicemesh/ingress/)に記載があるように、CiliumはIngressのサポートをしています。
そのため、Ciliumの機能でトラフィックのルーティングが可能です。
この節では、IngressClassとしてCiliumを利用したトラフィックルーティングを行います。

まずingressControllerを有効にしたCiliumをアプライします。

```bash
helmfile apply -f helmfile
```

`ingressClassName`フィールドに`cilium`を設定したIngressをアプライすればIngressリソースを利用できます。

```bash
kubectl apply -f ingress.yaml
```

```bash
curl hubble.cilium.example.com
```

## L7-Aware Traffic Management

次にL7-Aware Traffic Managementについて説明します。

Ciliumでは、CRDとして定義された`CiliumEnvoyConfig`と`CiliumCllusterwideEnvoyConfig`を利用してL7トラフィックの制御を行います。
この機能を利用するためには、`type:NodePort`の有効化またはkube-proxyの置き換えが必要になります。
詳細は[L7-Aware Traffic Management#Prerequisites](https://docs.cilium.io/en/latest/network/servicemesh/l7-traffic-management/)を参照してください。


Ciliumでは、Envoy API v3のみサポートされており、Envoy Extension Resource Typeへの対応状況は[Envoy extensions configuration file](https://github.com/cilium/proxy/blob/main/envoy_build_config/extensions_build_config.bzl)から確認可能です。

今回は、[L7 Traffic Shifting](https://docs.cilium.io/en/latest/network/servicemesh/envoy-traffic-shifting/)で説明される`envoy.filters.http.router`を利用したトラフィックシフトを行います。

まず、アプリケーションのデプロイを行います。

```bash
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/envoy/client-helloworld.yaml
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/envoy/helloworld-service-v1-v2.yaml
```

`helloworld-v1`に90%、`helloworld-v2`に10%のトラフィックを流すように設定します。

```bash
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/envoy/helloworld-service-v1-v2.yaml
```

下記コマンドを実行すると、`helloworld-v1`に90%、`helloworld-v2`に10%のトラフィックが流れることが確認できます。

```bash
CLIENT=$(kubectl get pods -l name=client -o jsonpath='{.items[0].metadata.name}')
for i in {1..10}; do  kubectl exec -it $CLIENT -- curl  helloworld:5000/hello; done
```

