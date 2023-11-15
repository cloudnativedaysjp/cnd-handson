# Chapter 4d Hubble

## はじめに

この節ではHubbleを利用したフロー情報の可視化について説明します。

## Hubbleの概要

HubbleはCiliumのために開発されたネットワークとセキュリティのObservabilityプラットフォームであり、
[Cilium Hubble Series (Part 1): Re-introducing Hubble](https://isovalent.com/blog/post/hubble-series-re-introducing-hubble/)で説明されるように下記のコンポーネントで構成されます。

![](image/ch05_hubble-components_01.png)

- Hubble Server
  - 各NodeのCilium Agentに組み込まれており、Prometheusメトリクスやネットワークおよびアプリケーションプロトコルレベルでのフロー情報の可視性を提供します
- Hubble Relay
  - クラスターをスコープとするHubble APIを提供します
- Hubble UI
  - グラフィカルなサービス依存関係マップと接続性マップを提供します
- Hubble CLI
  - コマンドラインバイナリであり、Hubble RelayのgRPC APIまたはローカルサーバーのいずれかに接続してフローイベントを取得します


## 構築

Hubble RelayとHubble UIのステータスを確認します。
ステータスはciliumコマンドからも確認可能です。

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

設定自体はすでに[Chapter1 Cluster Create](./../chapter01_cluster-create)で行っているため、Hubble-uiおよびHubble-relayが動作しています。
Hubble RelayとHubble UIのデプロイはそれぞれ`hubble.relay.enabled=true`と`hubble.ui.enabled=true`で設定可能です。
また、Ciliumが管理するKubernetes Podのネットワークを監視するために、Hubbleのメトリクスを有効化しています。
使用可能なメトリクスに関しては、[Hubble Exported Metrics](https://docs.cilium.io/en/stable/observability/metrics/#hubble-exported-metrics)を参照ください。

具体的な設定は以下のようなモノになります。

```yaml
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
    podAnnotations:
      policy.cilium.io/proxy-visibility: "<Ingress/8081/TCP/HTTP>"
  metrics:
    enableOpenMetrics: true
    # see: https://docs.cilium.io/en/stable/observability/metrics/#hubble-metrics
    enabled:
      - dns
      - drop
      - tcp
      - flow
      - port-distribution
      - icmp
      - httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_ip,destination_namespace,destination_workload,traffic_direction
```

Hubble UIに関しては、L7トラフィックの可視化を行うためにannotationに`policy.cilium.io/proxy-visibility: "<Ingress/8081/TCP/HTTP>"`を設定します。
こちらについては後述します。

## 動作確認

### Hubble Relayへのアクセス

概要で説明した通り、Hubble Relayへアクセスする方法として、下記の2種類の方法があります。

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
やり方はいろいろありますが、今回はkubectlコマンドを利用します。

```shell
# 別のコンソールを開き実行
kubectl port-forward -n kube-system deploy/hubble-relay 4245 4245
```
```shell
Forwarding from 127.0.0.1:4245 -> 4245
Forwarding from [::1]:4245 -> 4245
```

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

ブラウザで`hubble.example.com`にアクセスしingress-nginxのnamespaceを確認すると、下記のような画面が出力されます。
これより、インターネット側からingress-nginxの80ポートにアクセスがあり、その後hubble-uiの8081ポートにアクセスされたことが分かります。

![](./image/ch05_hubble-ui_01.png)

### Layer 7プロトコルの可視化

[Layer 7 Protocol Visibility](https://docs.cilium.io/en/latest/observability/visibility/#layer-7-protocol-visibility)に記載があるように、L7プロトコルの可視化を行うことも可能です。L7プロトコルの可視化はannotationで設定します。
たとえば、Hubble-UIの8081ポートへのIngress方向のHTTP通信の可視化を行う場合、下記のannotationをHubble-UIのPodに設定します。

```yaml
policy.cilium.io/proxy-visibility: "<Ingress/8081/TCP/HTTP>"
```

また、CiliumEndpointsを確認することで、Visibility Policyのステータスを確認することが可能です。

```shell
kubectl get cep -n kube-system
```
```shell
# 実行結果
NAME                            ENDPOINT ID   IDENTITY ID   INGRESS ENFORCEMENT   EGRESS ENFORCEMENT   VISIBILITY POLICY   ENDPOINT STATE   IPV4         IPV6
coredns-5d78c9869d-99cjz        2133          63980         non-enforcing         non-enforcing                            ready            10.0.1.202
coredns-5d78c9869d-nn2bc        2155          63980         non-enforcing         non-enforcing                            ready            10.0.1.159
hubble-relay-645b6cb9f8-tjdjw   2710          21510         non-enforcing         non-enforcing                            ready            10.0.2.12
hubble-ui-5f7b57789f-jrmt8      2931          3711          non-enforcing         non-enforcing        OK                  ready            10.0.2.189
```

> **Info**  
> 下記コマンドでannotationを削除することで、Visibility Policyを無効化できます。
> ```
> kubectl annotate -n kube-system pod -l app.kubernetes.io/name=hubble-ui policy.cilium.io/proxy-visibility-
> ```

annotationで可視化の設定を行うことで、Hubble-UIからL7プロトコルの情報を確認できます。

## Grafanaを利用した可視化について

CiliumとHubbleから取得したメトリクスはGrafanaのダッシュボードから確認可能です。
[Monitoring & Metrics](https://docs.cilium.io/en/stable/observability/metrics/)に記載があるように、
Ciliumからはcilium-agentやcilium-envoy、cilium-operatorに関するCilium自身のメトリクスを取得でき、
HubbleからはCiliumが管理するPodのネットワーク動作に関するメトリクスを取得できます。

Grafanaのダッシュボードにアクセスすると以下のようなダッシュボードが確認できます。

![](./image/ch05_hubble-grafana_01.png)
