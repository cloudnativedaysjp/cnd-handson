# Prometheus

この章では、Kubernetes上での様々なメトリクスの基盤としてPrometheusを紹介し、実際に導入してみます。

## Prometheusについて

Prometheusはモニタリング/アラートに関する基盤として利用することができるOSSです(元はSoundCloud)。
2016年にCloud Native Computing Foundation Projectに加わり、現在はGraduatedとなっています。

メトリクス収集についてはプル型アーキテクチャ(PushGatewayという仕組みによってサービスからプッシュも可能)によって実現されています。

## PromQLについて

Prometheusが提供するメトリクスのクエリ言語で、多次元的にラベルがつけられた時系列データに対して様々な計算を適用可能になっています。
例えば、以下の式では特定の環境で、GET以外のHTTPリクエストメソッドを持つリクエスト数のデータを取得することができます。

```text
http_requests_total{environment=~"staging|testing|development",method!="GET"}
```

## Prometheus Operatorについて

Prometheus Operatorは、Prometheusや関連する監視コンポーネントを管理やKubernetesネイティブなデプロイメントを提供します。
このプロジェクトの目的は、KubernetesクラスターのPrometheusベースの監視スタックの設定を簡素化し、自動化することにあります。

Prometheus Operatorには以下の特徴があります。

Kubernetesカスタムリソース：Kubernetesのカスタムリソースを使用して、PrometheusやAlertmanager、関連するコンポーネントをデプロイし、管理します。

簡素化されたデプロイメント設定：Prometheusの基本設定であるバージョン、永続性、保持ポリシー、KubernetesリソースのReplicaなどを設定することができます。

Prometheusターゲット設定：Prometheus固有の言語を学ぶ必要なく、Kubernetesラベルクエリに基づいて監視ターゲット設定を自動的に生成します。

![image](https://prometheus-operator.dev/img/architecture.png)

### メトリクスの収集

メトリクスを収集するために、Prometheus Operator は `ServiceMonitor`や`PodMonitor`を使用して、監視対象のサービスを指定します。

これにより、CPUやメモリ使用率、HTTPリクエスト数、レイテンシーなどのメトリクスを追跡できます。

例として、replicaが3つでport`8080`で以下のようなアプリケーションが公開されていることに前提に説明していきます。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      containers:
        - name: example-app
          image: fabxc/instrumented_app
          ports:
            - name: web
              containerPort: 8080
---
kind: Service
apiVersion: v1
metadata:
  name: example-app
  labels:
    app: example-app
spec:
  selector:
    app: example-app
  ports:
    - name: web
      port: 8080
```

### ServiceMonitorの設定

`ServiceMonitor`オブジェクトは、サービスのエンドポイントからメトリクスを収集することができます。

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: example-app
  labels:
    team: frontend
spec:
  selector:
    matchLabels:
      app: example-app
  endpoints:
    - port: web
```

### PodMonitorの設定

`PodMonitor`オブジェクトは、個々のポッドから直接メトリクスを収集することができます。

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: example-app
  labels:
    team: frontend
spec:
  selector:
    matchLabels:
      app: example-app
  podMetricsEndpoints:
    - port: web
```

![image](https://prometheus.io/assets/grafana_prometheus.png)

## 実践: kube-prometheus-stackのインストール

KubernetesクラスタにPrometheusをインストールする方法として、
Prometheusおよび各種ExporterをDaemonset等でデプロイする方法もありますが、
ここではkube-prometheus-stackというHelm Chartを利用したいと思います。

kube-prometheus-stackでは以下のようなコンポーネントをまとめてインストールすることができ、
各種設定もvalues.yamlで宣言的におこなうことができるため、導入/管理が比較的かんたんに実現できます。

- Prometheus
- Grafana
- AlertManager
- kube-state-metrics
- Node Exporter
- Prometheus Operator

用意されているhelmfile.yamlおよびvalues.yamlを利用して、 `helmfile sync` を実行しreleaseをインストールしましょう。

```bash
helmfile sync -f helm/helmfile.yaml
```

実際に各種サービスが起動しているか確認してみましょう。

```bash
kubectl get pods -n prometheus
```

```bash
# 実行結果
alertmanager-kube-prometheus-stack-alertmanager-0           2/2     Running   0          92s
kube-prometheus-stack-grafana-5f4bf8df47-5csmk              3/3     Running   0          100s
kube-prometheus-stack-kube-state-metrics-776cff966c-x4v7w   1/1     Running   0          100s
kube-prometheus-stack-operator-fdc594c4d-6896k              1/1     Running   0          100s
kube-prometheus-stack-prometheus-node-exporter-7972j        1/1     Running   0          100s
kube-prometheus-stack-prometheus-node-exporter-dbkqx        1/1     Running   0          100s
kube-prometheus-stack-prometheus-node-exporter-jqk58        1/1     Running   0          100s
kube-prometheus-stack-prometheus-node-exporter-tm89f        1/1     Running   0          100s
prometheus-kube-prometheus-stack-prometheus-0               2/2     Running   0          92s
```

### Ingressによるサービスの公開

続いて、PrometheusやGrafana等の各UIをIngressで公開していきます。
すでにIngress NGINX Controllerがデプロイされていると思うので、以下のような設定でIngressをデプロイして公開します。

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress-by-nginx
  namespace: prometheus
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
    - host: grafana.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kube-prometheus-stack-grafana
                port:
                  number: 80

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress-by-nginx
  namespace: prometheus
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
    - host: prometheus.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kube-prometheus-stack-prometheus
                port:
                  number: 9090
```

```bash
kubectl apply -f ingress.yaml
```

実際にそれぞれのUIが公開されているか確認してみましょう。
ブラウザで `prometheus.example.com` と `grafana.example.com` にアクセスしてみてください。

Grafanaではユーザログインが必要ですが、先程設定したvalues.yamlの内容でログインできます( `username: admin, password: handson_saiko!` )
values.yamlに記載した認証情報でログインできなかった場合は、
以下のコマンドを実行してパスワードを確認し、ログインしてください。

```bash
kubectl get secrets -n prometheus kube-prometheus-stack-grafana -o json | jq -r .data[\"admin-password\"] | base64 -d; echo
```

## 実践: Prometheus Web UIを触ってみよう

### PromQL

Prometheus Web UIでは、PromQLを利用してインタラクティブに簡単なモニタリングをおこなうことができます。
ここではkube-prometheus-stackがデフォルトでインストールするExporterの様子を掴むために、
実際にPromQLを使ってメトリクスを見てみましょう。
PromQLの詳細な仕様についてはこちらを御覧ください。

> https://prometheus.io/docs/prometheus/latest/querying/basics/

<http://prometheus.example.com/graph> にアクセスして、PromQL入力欄に `go_goroutines` と入力してみます。
その後、 `Graph` のタブをクリックすると、以下のようなグラフが見れるはずです。

![image](./image/go_goroutines.png)

これは、Go言語で実装されたExporterでよく公開されている、現在のgoroutineの発行数となるメトリックです。
これはGaugeとなっているので、単調増加ではなく微妙に増減しているのが確認できます。
後ほど、いくつかのPromQL実践例を紹介します。

### Alerts

kube-prometheus-stackでデフォルトで導入されているアラートルールを確認することができます。

<http://prometheus.example.com/alerts>

![image](./image/alerts.png)

### Status

現在稼働しているPrometheusの状態確認がおこなえます。
以下のスクリーンショットでは、scrape_configに設定されたexporterに対するスクレイプが正しくおこなえているかどうか等の情報が表示されています。

<http://prometheus.example.com/targets>

![image](./image/targets.png)

## 実践: Ingress NGINX Controllerからメトリクスを収集する

ここでは、`Ingress NGINX Controller`のメトリクスをPrometheusとGrafanaによる収集方法を説明します。

- `emptyDir`をPrometheusとGrafanaに使っている場合は、データを失う可能性があるので気をつけてください。

### Nginx Ingressのメトリクスを外部公開する

Ingress NGINX Controllerのメトリクスを外部公開するために、ServiceMonitorを作成し、PrometheusがIngress NGINX Controllerのメトリクスを取得するようにします。

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  endpoints:
    - port: metrics
      interval: 30s
  namespaceSelector:
    matchNames:
      - ingress-nginx
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/instance: ingress-nginx
      app.kubernetes.io/component: controller
```

```shell
kubectl apply -f manifests/ingress-nginx-servicemonitor.yaml
```

<http://prometheus.example.com/graph> を開き (またはリロードして)、PromQL入力欄に ngi と入力し、nginx のメトリクスが追加されているのを確認しましょう。

![image](https://github.com/kubernetes/ingress-nginx/blob/main/docs/images/prometheus-dashboard1.png)

## PromQL実例集

ここでは、 <https://prometheus.io/docs/prometheus/latest/querying/basics/> の内容をもとに、
PromQLでよく使われる表現をいくつか見ていきたいと思います。

より包括的なチートシートとしては、 <https://promlabs.com/promql-cheat-sheet/> も参考になります。

```text
# Instant Vector(http_requests_totalにおける、サンプリングデータの集合)
http_requests_total

# Instant Vector with Selector(http_requests_totalのうち、指定したラベルを持つデータの集合)
http_requests_total{job="prometheus",group="canary"}

# Instant Vector with Matching Expression
http_requests_total{environment=~"staging|testing|development",method!="GET"}

# Range Vector(過去5分間における、http_requests_totalのデータ)
http_requests_total{job="prometheus"}[5m]

# Built-in function with Range Vector(過去5分間における、http_requests_totalの平均)
# 各組み込み関数のシグネチャはこちら https://prometheus.io/docs/prometheus/latest/querying/functions/#aggregation_over_time
avg_over_time(http_requests_total{job="prometheus"}[5m])

# Aggregation Operators(application, groupごとに集計したhttp_requests_totalの合計)
 sum by (application, group) (http_requests_total)

# 実例1(利用可能になっているKubernetes Nodeの数)
sum(kube_node_status_condition{condition="Ready", status="true"}==1)

# 実例2(Namespaceごとに集計した、準備可能になっていないPodの数)
sum by (kube_namespace_name) (kube_pod_status_ready{condition="false"})
```

## 参考文献

- [Prometheusの公式ドキュメント](https://prometheus.io/docs/introduction/overview/)
- [Prometheus Operatorの公式ドキュメント](https://prometheus-operator.dev/)
- [Nginx Ingressのメトリクス収集](https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/monitoring.md)
