# Prometheus Operatorについて

## 概要

Prometheus Operatorは、Prometheusや関連する監視コンポーネントを管理やKubernetesネイティブなデプロイメントを提供します。
このプロジェクトの目的は、KubernetesクラスターのPrometheusベースの監視スタックの設定を簡素化し、自動化することです。

Prometheus Operatorには以下の特徴があります。

Kubernetesカスタムリソース：Kubernetesのカスタムリソースを使用して、PrometheusやAlertmanager、関連するコンポーネントをデプロイし、管理します。

簡素化されたデプロイメント設定：Prometheusの基本設定であるバージョン、永続性、保持ポリシー、KubernetesリソースのReplicaなどを設定することができます。

Prometheusターゲット設定：Prometheus固有の言語を学ぶ必要なく、Kubernetesラベルクエリに基づいて監視ターゲット設定を自動的に生成します。

![image](https://prometheus-operator.dev/img/architecture.png)

## ハンズオン

ここでは、repricaが3つでport`8080`で公開されているアプリケーションを参考に説明していきます。

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

### メトリクスの収集

メトリクスを収集するために、Prometheus Operator は `ServiceMonitor`や`PodMonitor`を使用して、監視対象のサービスを指定します。

これにより、CPUやメモリ使用率、HTTPリクエスト数、レイテンシーなどのメトリクスを追跡できます。

#### ServiceMonitorの設定

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

#### PodMonitorの設定

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

**TODO Service Monitor設定後にサンプル画像を載せる**

### Alerting機能

Prometheus Operatorは`Alertmanager`リソースを導入しており、これによりユーザーはAlertmanagerクラスターを宣言的に記述することができます。

Alertmangerには下記の役割があります。

- Prometheusから受け取ったアラートの重複削除
- アラートの無視
- まとめた通知を様々な統合システム（PagerDuty、OpsGenie、メール、チャットなど）にルーティングして送信する

#### Alertmanagerのデプロイ

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Alertmanager
metadata:
  name: example
spec:
  replicas: 3
```

#### Alertmanagerの設定

デフォルトでAlertmanagerのインスタンスでは、アラートが発生しても通知されない最低限の設定されています。

以下の方法でAlertmanagerの設定をすることができます。

1. Kubernetes Secretに保存されたネイティブのAlertmanager設定ファイルを使用することができます。
2. `AlertmanagerConfig`オブジェクトの`spec.alertmanagerConfiguration`を使用して、同じネームスペース内にあるAlertmanagerの主要な設定を定義するAlertmanagerConfigオブジェクトを参照できます。
3. `AlertmanagerConfig`オブジェクトの`spec.alertmanagerConfigSelector`と`spec.alertmanagerConfigNamespaceSelector`を定義することで、どのAlertmanagerConfigsオブジェクトを選択し、主要なAlertmanager設定とマージするかをオペレーターに指示できます。

#### AlertmanagerConfigを使う方法

今回は、`AlertmanagerConfig`を使った方法で説明していきます。

Webhookサービスに通知を送信するAlertmanagerConfigリソースを作成します。

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: config-example
  labels:
    alertmanagerConfig: example
spec:
  route:
    groupBy: ['job']
    groupWait: 30s
    groupInterval: 5m
    repeatInterval: 12h
    receiver: 'webhook'
  receivers:
  - name: 'webhook'
    webhookConfigs:
    - url: 'http://example.com/'
```

Alaertmanagerの`spec.alertmanagerConfigSelector`にAlertmanagerConfigの`metadata.labels.alertmanagerConfig`を指定します。

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Alertmanager
metadata:
  name: example
spec:
  replicas: 3
  alertmanagerConfigSelector:
    matchLabels:
      alertmanagerConfig: example
```

### Alerting Rule

Prometheus Operatorでは、`PrometheusRule`オブジェクトを使用してアラートルールを設定します。

アラートルールを定義することで、特定の条件が満たされた場合（例えば、メモリ使用率が閾値を超えた場合）に通知を受け取ることができます。

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: example-alert
  labels:
    release: [RELEASE_NAME]
spec:
  groups:
  - name: example
    rules:
    - alert: HighRequestLatency
      expr: job:request_latency_seconds:mean5m{job="example-job"} > 0.5
      for: 10m
      labels:
        severity: page
      annotations:
        summary: High request latency
```

## 参考文献

https://prometheus-operator.dev/
