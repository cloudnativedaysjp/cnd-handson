# Chapter 04d Cilium

[What is Cilium](https://cilium.io/get-started/)で説明されるように、CiliumはKubernetesクラスターやその他のクラウドネイティブ環境にネットワーキング、セキュリティ、可観測性を提供するオープンソースプロジェクトです。
Ciliumの基盤となっているのは、eBPFと呼ばれるLinuxカーネルの技術であり、セキュリティや可視性、ネットワーク制御ロジックをLinuxカーネルに動的に挿入することを可能としています。

また、[Component Overview](https://docs.cilium.io/en/stable/overview/component-overview/#component-overview)で説明されるように、Ciliumは下記の主要コンポーネントで構成されています。

- Agent
  - Kubernetesクラスターの各ノードで実行され、Kubernetes APIサーバーとの接続を確立し、ネットワーク及びセキュリティポリシーを維持する役割を果たします。
  - Linuxカーネルがコンテナーのネットワークアクセスを制御するために使用するeBPFプログラムの管理を行います。
- Client(CLI)
  - Cilium Agentとともにインストールされるコマンドラインツールです。
  - 同じノード上で動作するCilium AgentのREST APIと対話を行うことができ、Agentの状態やステータスの検査ができます。
  - Cliumのインストールや管理。トラブルシュートなどに使用されるCLIとは別物になります。
- Operator
  - クラスター全体の管理を行います。
  - 一時的に利用できなくてもクラスターは機能し続けますが、IPアドレス管理の遅延やAgentの再起動につながるkvstoreの不調の原因となります。
- CNI Plugin
  - PodがNode上でスケジュールまたは終了される時にKubernetesによって呼び出されます
  - Cilium APIと対話し、Networking、ロードバランシング、ネットワークポリシーを提供するために必要な設定を起動します。

```console
kubectl get po
```

この章ではCiliumの機能として下記について説明します

- NetworkPolicy
- Ingress
- Gateway API
- Service Mesh

## Network Policy

[Network Policy](https://docs.cilium.io/en/stable/network/kubernetes/policy/#network-policy)にもある通り、Ciliumでは3種類のリソースでトラフィックを制御できます。

- NetworkPolicy
  - PodのIngress/EgressでL3/L4ぽレイシーをサポートするリソースです。
  - 詳細は[Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)を参照してください。
- CiliumNetworkPolicy
  - NetworkPolicyリソースとよく似ており、サポートされていない機能を提供することを目的としています。
  - L3-L7のポリシーをポリシーを設定可能です。
- CiliumClusterwideNetworkPolicy
  - クラスター全体のポリシーを設定するためのリソースです
  - CiliumNetworkPolicyと同じ設定が可能ですが、名前空間の指定はありません

この節ではCiliumNetworkPolicyの動作確認を行います。

```console
kubectl run curl-allow -n handson --image=curlimages/curl --labels="app=curl-allow" --command -- sleep infinity
kubectl run curl-deny  -n handson --image=curlimages/curl --labels="app=curl-deny"  --command -- sleep infinity
```

現状は`curl-allow`/`curl-deny`の両方から`/`と`/color`にアクセスできることを確認します。

```console
kubectl exec -n handson curl-allow -- /bin/sh -c "echo -n 'curl-allow: ';curl -s -o /dev/null handson:80 -w '%{http_code}\n'"
kubectl exec -n handson curl-deny  -- /bin/sh -c "echo -n 'curl-deny:  ';curl -s -o /dev/null handson:80 -w '%{http_code}\n'"
kubectl exec -n handson curl-allow -- /bin/sh -c "echo -n 'curl-allow:color: ';curl -s -o /dev/null handson:80/color -w '%{http_code}\n'"
kubectl exec -n handson curl-deny  -- /bin/sh -c "echo -n 'curl-deny:color:  ';curl -s -o /dev/null handson:80/color -w '%{http_code}\n'"
```

動作確認として下記のような設定の`CiliumNetworkPolicy`をデプロイしてみます。
- `/`へは`curl-allow`からのみアクセス可能
- `/color`へは`curl-allow`と`curl-deny`の両方からアクセスが可能

```console
kubectl apply -f manifest/cnp_ch4d-1.yaml
```

実際にアクセスし確認すると、想定通りの動作になっていることが分かります。

```console
kubectl exec -n handson curl-allow -- /bin/sh -c "echo -n 'curl-allow: ';curl -s -o /dev/null handson:80 -w '%{http_code}\n'"
kubectl exec -n handson curl-deny  -- /bin/sh -c "echo -n 'curl-deny:  ';curl -s -o /dev/null handson:80 -w '%{http_code}\n'"
kubectl exec -n handson curl-allow -- /bin/sh -c "echo -n 'curl-allow:color: ';curl -s -o /dev/null handson:80/color -w '%{http_code}\n'"
kubectl exec -n handson curl-deny  -- /bin/sh -c "echo -n 'curl-deny:color:  ';curl -s -o /dev/null handson:80/color -w '%{http_code}\n'"
```

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









