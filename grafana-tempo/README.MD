# Grafana Tempo
## 概要
Grafana Tempo は、オープンソースで使いやすく、大規模な分散トレース バックエンドです。 Tempo はコスト効率が高く、動作にはオブジェクト ストレージのみが必要で、Grafana、Prometheus、Loki と緊密に統合されています。

Tempo は、Jaeger、Zipkin、Kafka、OpenCensus、OpenTelemetry と互換性があります。前述の形式のいずれかでバッチを取り込み、バッファリングして、Azure、GCS、S3、またはローカル ディスクに書き込みます。そのため、堅牢で安価、そして操作が簡単です。

Tempo は、LogQL と PromQL からインスピレーションを得たトレースファーストのクエリ言語であるTraceQLを実装しています。このクエリ言語を使用すると、ユーザーは非常に正確かつ簡単にスパンを選択し、指定された条件を満たすスパンに直接ジャンプできます。
## アーキテクチャ
![](https://grafana.com/docs/tempo/latest/operations/tempo_arch.png)
Tempo の主要コンポーネントの概要を説明します。
Tempoは以下のコンポーネントで構成されています。
- Distributor
- Ingester
- Query Frontend
- Querier
- Compactor
- Metrics generator
またストレージとして以下の2つが使われています。
- Cache(Redis Memcached)
- Object Storage(S3 GCS Azure)
## デプロイ方法
## Trace QLの概要
## セットアップ
この章を行うには2章でPrometheusとGrafanaを4章でOpentelemetryをデプロイしておく必要があります。
```
helmfile sync -f helm/helmfile.yaml
```
```
kubectl get pod -n monitoring
NAME                                      READY   STATUS    RESTARTS   AGE
grafana-tempo-0                           1/1     Running   0          102s
opentelemetry-operator-569f6b668c-zrzdb   2/2     Running   0          23h
```
デプロイが完了したら次にGrafanaにTempoを追加する設定を行います。
http://grafana-tempo.monitoring.svc.cluster.local:3100

## search
## TraceQL
## Service Graph