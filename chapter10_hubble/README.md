# Hubble

## はじめに

この節ではHubbleを利用したフロー情報の可視化について説明します。

## Hubbleの概要

HubbleはCiliumのために開発されたネットワークとセキュリティのObservabilityプラットフォームであり、
[Cilium Hubble Series (Part 1): Re-introducing Hubble](https://isovalent.com/blog/post/hubble-series-re-introducing-hubble/)で説明されるように、下記のコンポーネントで構成されます。

![](image/ch05_hubble-components_01.png)

（出典：https://isovalent.com/blog/post/hubble-series-re-introducing-hubble/）

- Hubble Server
  - 各NodeのCilium Agentに組み込まれており、Prometheusメトリクスやネットワークおよびアプリケーションプロトコルレベルでのフロー情報の可視性を提供します
- Hubble Relay
  - クラスターをスコープとするHubble APIを提供します
- Hubble UI
  - グラフィカルなサービス依存関係マップと接続性マップを提供します
- Hubble CLI
  - コマンドラインバイナリであり、Hubble RelayのgRPC APIまたはローカルサーバーのいずれかに接続してフローイベントを取得します


## ステータス確認

Hubble RelayとHubble UIのステータスはciliumコマンドから確認可能です。

```shell
cilium status
```

```shell
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    disabled (using embedded mode)
 \__/¯¯\__/    Hubble Relay:       OK
    \__/       ClusterMesh:        disabled

Deployment             hubble-relay       Desired: 1, Ready: 1/1, Available: 1/1
Deployment             cilium-operator    Desired: 2, Ready: 2/2, Available: 2/2
DaemonSet              cilium             Desired: 3, Ready: 3/3, Available: 3/3
Deployment             hubble-ui          Desired: 1, Ready: 1/1, Available: 1/1
Containers:            cilium-operator    Running: 2
                       hubble-ui          Running: 1
                       hubble-relay       Running: 1
                       cilium             Running: 3
Cluster Pods:          12/12 managed by Cilium
Helm chart version:    1.14.2
Image versions         cilium             quay.io/cilium/cilium:v1.14.2@sha256:6263f3a3d5d63b267b538298dbeb5ae87da3efacf09a2c620446c873ba807d35: 3
                       cilium-operator    quay.io/cilium/operator-generic:v1.14.2@sha256:52f70250dea22e506959439a7c4ea31b10fe8375db62f5c27ab746e3a2af866d: 2
                       hubble-ui          quay.io/cilium/hubble-ui-backend:v0.12.0@sha256:8a79a1aad4fc9c2aa2b3e4379af0af872a89fcec9d99e117188190671c66fc2e: 1
                       hubble-ui          quay.io/cilium/hubble-ui:v0.12.0@sha256:1c876cfa1d5e35bc91e1025c9314f922041592a88b03313c22c1f97a5d2ba88f: 1
                       hubble-relay       quay.io/cilium/hubble-relay:v1.14.2@sha256:a89030b31f333e8fb1c10d2473250399a1a537c27d022cd8becc1a65d1bef1d6: 1
```

設定自体はすでに[Chapter1 Cluster Create](./../chapter01_cluster-create)で行っているため、Hubble-uiとHubble-relayが動作しています。
Helmを利用してアプライする場合、Hubble RelayとHubble UIのデプロイはそれぞれ`hubble.relay.enabled=true`と`hubble.ui.enabled=true`で設定可能です。
また、Ciliumが管理するKubernetes Podのネットワークを監視するために、Hubbleのメトリクスを有効化する設定を入れています。
使用可能なメトリクスに関しては、[Hubble Exported Metrics](https://docs.cilium.io/en/stable/observability/metrics/#hubble-exported-metrics)を参照ください。

## 動作確認

### Hubble Relayへのアクセス

概要で説明した通り、Hubble Relayへアクセスする方法として下記の2種類の方法があります。

- Hubble CLIを利用する方法
- Hubble UIを利用する方法

それぞれについて説明します。

### Hubble CLIの利用

Hubble CLIを利用してHubble Relayにアクセスします。

まずは、Hubble CLIをインストールします。

```shell
./install-tools.sh
```

次に、Hubble RelayへのReachabilityを確保します。
別のターミナルを開き、下記コマンドを実行することでReachabilityを確保できます。

```shell
cilium hubble port-forward
```

> [!NOTE]
> 
> cilium hubble port-forwardコマンドを実行しても何も表示されません。
> 別ターミナルを開き、以降を進めてください。

下記コマンドでStatusを確認し、HealthcheckがOKとなっていることを確認します。

```shell
hubble status
```
```shell
Healthcheck (via localhost:4245): Ok
Current/Max Flows: 7,479/12,285 (60.88%)
Flows/s: 33.34
Connected Nodes: 3/3
```

> [!NOTE]
>   
> ciliumコマンドではなく、下記のようなkubectlコマンドを実行することでもReachabilityを確保可能です。
> ```shell
> kubectl port-forward -n kube-system deploy/hubble-relay 4245 4245
> ```


Hubble Relay経由で取得したHubble Serverのフロー情報は、下記コマンドで出力できます。

```shell
hubble observe flows
```

コマンドを実行すると下記のような情報が出力されます。

![](./image/ch05_hubble-observe-flows_01.png)

### Hubble UIの利用

Hubble UIからHubble Relayにアクセスし、Hubble Serverの情報を取得します。

Hubble UIへアクセスするために、Ingressリソースを作成します。

```shell
kubectl apply -f manifest/ingress.yaml
```

ブラウザで`hubble.cilium.example.com:8080`にアクセスしkube-systemのnamespaceを確認すると、下記のような画面が出力されます。
これより、インターネット側からingress-nginxの80ポートにアクセスがあり、その後hubble-uiの8081ポートにアクセスしていることが分かります。

![](./image/ch05_hubble-ui_01.png)

### Layer 7のイベントを可視化する

デフォルトではL3/L4のイベントのみ可視化の対象となっています。
L7のイベントを可視化の対象とするためには、CiliumNetworkPolicyリソースを作成し、CiliumNetworkPolicyのルールに一致させる必要があります。

> [!NOTE]
> 
> L7プロトコルを可視化する方法として、Podのannotationを利用する方法もありましたが、2023/11時点の最新のドキュメントではCiliumNetworkPolicyを利用する方法が推奨されています。  
> see: https://github.com/cilium/cilium/blob/82dbff8e5a5f7ced99e96cd85997fae90e035aac/Documentation/observability/visibility.rst

確認用にcurlを実行可能なクラアントを立てます。

```shell
kubectl run curl -n handson --image=curlimages/curl --command -- sleep infinity
```

別ターミナルを開き、hubbleで観測したイベントを流しておきます。

```shell
hubble observe flows --from-pod handson/curl -f
```

先ほど立てたクライアントからhandson:8080にアクセスしてみます。

```shell
kubectl exec -n handson curl -- /bin/sh -c "curl -s -o /dev/null handson:8080 -w '%{http_code}\n'"
```

するとhubble側では下記のような情報が出力されます。

![](./image/ch5-hubble-observe-01.png)


L3/L4のイベントが可視化されており、ドメイン名やリクエストパスなどのL7の情報が表示されていないことが分かります。  
L7のイベントを可視化の対象とするために、ポート8080への通信がルールに含まれる下記CiliumNetworkPolicyを適用します。

```shell
kubectl apply -f manifest/cnp_http-visibility.yaml
```

先ほどと同様に、クライアントから`handson:8080`にアクセスしてみます。

```shell
kubectl exec -n handson curl -- /bin/sh -c "curl -s -o /dev/null handson:8080 -w '%{http_code}\n'"
```

今回はhandson:8080宛の通信がCiliumNetworkPolicyの対象となるため、hubble側でL7の情報が確認できるようになります。

![](./image/ch5-hubble-observe-02.png)

### 外部ドメインを可視化する

クラスター外のドメインはkube-dnsやCoreDNSといったクラスター内のDNSサーバで解決されます。
DNSサーバへの通信を可視化の対象とすることで、通信が発生した外部ドメインを確認することが可能になります。

まず、現在の状態でクラスター外のドメイン`event.cloudnativedays.jp`にアクセスしてみます。

```shell
kubectl exec -n handson curl -- /bin/sh -c "curl -s -o /dev/null https://event.cloudnativedays.jp/ -w '%{http_code}\n'"
```

すると、下記のIPアドレスにアクセスがあることが分かります。

![](./image/ch5-hubble-observe-03.png)

次に下記のManifestをアプライしてkube-dnsへの通信をCiliumNetworkPolicyのルールに含めます。

```shell
kubectl apply -f manifest/cnp_dns-visibility.yaml
```

再度、クラスター外のドメイン`event.cloudnativedays.jp`にアクセスしてみます。

```shell
kubectl exec -n handson curl -- /bin/sh -c "curl -s -o /dev/null https://event.cloudnativedays.jp/ -w '%{http_code}\n'"
```

すると、DNSクエリが可視化の対象となり、IPアドレスではなく、どのドメインにアクセスしたのかが分かるようになります。

![](./image/ch5-hubble-observe-04.png)

また、上記の情報はHubble-UIからも確認可能です。

![](./image/ch5-hubble-curl-01.png)


確認が終わったら本章でデプロイしたリソースを削除しておきます。

```shell
kubectl delete -Rf manifest
kubectl delete -n handson pod curl --force
```

## Grafanaを利用した可視化について

CiliumとHubbleから取得したメトリクスはGrafanaのダッシュボードから確認可能です。
[Monitoring & Metrics](https://docs.cilium.io/en/stable/observability/metrics/)に記載があるように、
Ciliumからはcilium-agentやcilium-envoy、cilium-operatorに関するCilium自身のメトリクスを取得でき、
HubbleからはCiliumが管理するPodのネットワーク動作に関するメトリクスを取得できます。

第2章でCilium/Hubbleに関するGrafanaダッシュボードも設定しているため、アクセスして確認してみてください。

![](./image/ch05_hubble-grafana_01.png)
