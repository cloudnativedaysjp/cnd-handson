# Prometheus Operatorについて

## 概要

Prometheus Operatorは、Prometheusや関連する監視コンポーネントを管理やKubernetesネイティブなデプロイメントを提供します。
このプロジェクトの目的は、KubernetesクラスターのPrometheusベースの監視スタックの設定を簡素化し、自動化することです。

Prometheus Operatorには以下の特徴があります。

Kubernetesカスタムリソース：Kubernetesのカスタムリソースを使用して、PrometheusやAlertmanager、関連するコンポーネントをデプロイし、管理します。

簡素化されたデプロイメント設定：Prometheusの基本設定であるバージョン、永続性、保持ポリシー、KubernetesリソースのReplicaなどを設定することができます。

Prometheusターゲット設定：Prometheus固有の言語を学ぶ必要なく、Kubernetesラベルクエリに基づいて監視ターゲット設定を自動的に生成します。

## ハンズオン

### ServiceMonitorの設定

メトリクスを収集するために、Prometheus Operator は ServiceMonitor オブジェクトを使用して、監視対象のサービスを発見します。
ServiceMonitor は、収集するメトリクスのエンドポイント情報を指定します。

これにより、CPUやメモリ使用率、HTTPリクエスト数、レイテンシーなどのメトリクスを追跡できます。

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: example-service
  labels:
    release: [RELEASE_NAME]
spec:
  selector:
    matchLabels:
      app: example-app
  endpoints:
  - port: web
```

### Alertmanagerの設定

Prometheus Operator では、PrometheusRule オブジェクトを使用してアラートルールを設定します。

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
