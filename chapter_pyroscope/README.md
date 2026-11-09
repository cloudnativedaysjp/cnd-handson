# Pyroscope
この章では、オブザーバビリティの主要シグナルとして注目される、プロファイルについて紹介し、オブザーバビリティのバックエンドとして、GrafanaLabsのPyroscopeを導入します。

## プロファイルについて
**プロファイル**とは、ツールによりプログラム実行時の各種データを収集し、得られたデータの統計的な要約を行うことです。あるいは、そのデータのこともプロファイルと呼びます。また、プロファイルを収集する行為のことを、**プロファイリング**と呼びます。

メトリクスとは異なる概念で、アプリケーションがリソースをどのように消費しているかを断面的に見ることができ、リソース消費の多いプログラムを、即座に特定すること等に役立ちます。

## 従来のプロファイリング（非連続）と継続的プロファイリング

### 従来のプロファイリング（非連続）
従来のプロファイリングは、手動で記録を開始・停止する必要があり、開発環境での使用が中心でした。オーバーヘッドが高く、本番環境での継続的な実行は困難でした。

**例：Chrome DevTools**
1. DevToolsを開く（F12 または右クリック→検証）
2. Performanceタブを選択
3. 記録開始（▶︎ボタン）
4. 対象操作を実行
5. 記録停止（■ボタン）

![image](./image/chrome_profile.png)

### 継続的プロファイリング

継続的プロファイリングでは、低オーバーヘッドのサンプリングを使用して本番環境でも安全に実行でき、長期にわたってプロファイルを収集・分析できます。分散システム全体の動作把握に特に有効です。
継続的プロファイリングでは、オーバヘッドの低いサンプリングを使用して、プロファイルを安全に収集します。そのプロファイルはデータベースに保存するため、後で分析できます。

継続的プロファイリングを使用すると、分散サービス化しているアプリケーションが、本番環境でどのように動作するかを、全体的に把握することにも役立ちます。


## Pyroscopeについて
<img src="https://grafana.com/static/img/pyroscope-logo.svg" width="50">

**Pyroscope**は、Grafana Labsにより展開されている、継続的プロファイリングのOSS製品です。

元々、Grafana Phlare というプロジェクトがありましたが、2023/3 に、Grafana LabsがPyroscope社を買収し、Grafana Phlare と Pyroscope が統合され「Grafana Pyroscope」となりました。
2023/9 に v1.0.0 がリリースされています。

### Write（プロファイルの書き込み）

1. distributorがプロファイルを受け取り、segment-writerへ転送します。
2. segment-writerがプロファイルをオブジェクトストレージへ書き込みます。
3. metastoreがデータの場所を管理し、compaction-workerが保存されたデータを圧縮します。


### Read（プロファイルの読み込み）

1. query-frontendがクエリを受け取ります。
2. metastoreから対象データの場所を取得します。
3. query-backendがオブジェクトストレージからデータを読み出し、結果を返します。

詳細は[Pyroscope v2 architecture](https://grafana.com/docs/pyroscope/latest/reference-pyroscope-v2-architecture/)を参照してください。

## Pyroscopeへのプロファイルの送信（クライアント）
プロファイルをPyroscopeに送信するには、各言語向けのPyroscope SDKや、OTLP（OpenTelemetry Protocol）に対応した**Grafana Alloy**を利用できます。

当ハンズオンでは、初期構築時にGrafana Alloyがインストールされています。

> [!NOTE]
> Grafana AgentはEOLとなっており、Grafana Alloyへ移行されています。

## 実践: Grafana Pyroscopeのインストール
実践として、Pyroscopeをインストールします。以降のハンズオンででは、pyroscopeのchapterを作業ディレクトリとしてください。
```bash
cd ~/cnd-handson/chapter_pyroscope
```

Kubernetesクラスタ上にPyroscopeをインストールします。
ここでは、grafanaのHelm Chartから利用します。

Pyroscopeでは、モノリシックモードと、マイクロサービスモードという、2つのデプロイ方式が選択できます。本章ではv2ストレージアーキテクチャのマイクロサービスモードを採用します。

用意されているhelmfile.yamlおよび `helm/values-micro-services.yaml` を利用して、 `helmfile sync` を実行し、Pyroscopeをインストールしましょう。

```bash
helmfile sync -f helm/helmfile.yaml
```

Pyroscopeのプロファイルデータは、同時に導入されるS3互換ストレージのSeaweedFSに保存します。
認証情報はローカルハンズオン専用の固定値として自動設定されるため入力不要ですが、本番環境では使用しないでください。

実際に各種サービスが起動しているか確認します。

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/instance=pyroscope
```

```text
# 実行結果（マイクロサービスモード）
pyroscope-admin-xxxxxxxxxx-xxxxx              1/1     Running
pyroscope-alloy-0                             2/2     Running
pyroscope-compaction-worker-0                 1/1     Running
pyroscope-compaction-worker-1                 1/1     Running
pyroscope-distributor-xxxxxxxxxx-xxxxx        1/1     Running
pyroscope-metastore-0                         1/1     Running
pyroscope-query-backend-xxxxxxxxxx-xxxxx      1/1     Running
pyroscope-query-backend-xxxxxxxxxx-xxxxx      1/1     Running
pyroscope-query-backend-xxxxxxxxxx-xxxxx      1/1     Running
pyroscope-query-frontend-xxxxxxxxxx-xxxxx     1/1     Running
pyroscope-segment-writer-0                    1/1     Running
pyroscope-segment-writer-1                    1/1     Running
```


## Pyroscopeフロントエンドへのアクセス
Pyoscopeの画面にアクセスします。pyroscopeの画面を参照するために、HTTPRouteリソースを追加します。

```bash
kubectl apply -f httproute.yaml
```

[http://pyroscope.example.com](http://pyroscope.example.com)にアクセスしましょう。すでにPyroscope自身のプロファイルが確認できます。

![image](./image/pyroscope_web.png)


## Grafanaへのデータソース追加
chapter_grafanaで構築したGrafanaに、Pyroscopeのデータソースを追加します。
* Data sourse：Grafana Pyroscope
* HTTP>URL：http://pyroscope-query-frontend.monitoring.svc.cluster.local:4040

![image](./image/grafana-datasource.png)

※kube-prometheus-stackで使用したhelmのvaluesに追加する手順でも対応できます。
```yaml
datasources:
  - name: Grafana Pyroscope
    type: grafana-pyroscope-datasource
    url: http://pyroscope-query-frontend.monitoring.svc.cluster.local:4040
```

## Grafanaからのプロファイル参照
GrafanaのExplore([http://grafana.example.com/explore](http://grafana.example.com/explore))からプロファイルを見てみましょう。GarafanaのExploreでは、プロファイルタイプの選択と、ラベルセレクターでの絞り込みで、容易に表示できます。

プロファイルタイプは、cpu、memory、goroutineなどがあり、各言語ごとにサポートされています。詳細は、[Pyroscopeのドキュメント](https://grafana.com/docs/pyroscope/latest/view-and-analyze-profile-data/profiling-types/#available-profiling-types)を参照ください。

ラベルセレクターは、対象をtagで絞りたい場合に有効です。これは、Pyroscopeのclient側で付与されたtagになります。helmでinstallしたgrafana-agentでは、自動計装として使用可能なtagが付与されています。（[Pyroscope](http://pyroscope.example.com)のSingle View>Select Tagでの確認が簡単です。）空欄のままでもプロファイルを参照可能です。

<img src="./image/pyroscope-singleview.png" width="520">



1. プロファイルタイプを選択します。試しに、`process_cpu-cpu`を選択します。

<img src="./image/grafana-pyroscope-profiletype.png" width="320">

2. ラベルセレクターで、対象を絞り込みます。記法は`{<tag>=<value>}`です。 試しに、`{app_kubernetes_io_instance="pyroscope"}`を入力します。

<img src="./image/grafana-pyroscope-labelselector.png" width="600">

3. 「Run query」を実行して、プロファイルを表示します。

<img src="./image/grafana-pyroscope-queryview.png" width="700">


1. メトリクスも同時に表示できます。「Options」で表示項目を増やし、「Query Type」を「Both」にします。

<img src="./image/grafana-pyroscope-options.png" width="620">

5. 再度、「Run query」を実行すれば、メトリクスとプロファイルを同時に表示できます。（※「Query Type」を「Metric」にすれば、メトリクスだけ表示します）

<img src="./image/grafana-pyroscope-bothmetric.png" width="700">

## プロファイルの比較によるアプリケーションの改善
プロファイルは、ラベルセットや期間で比較することができ、パフォーマンスの変化を可視化できます。
たとえば、あるリリースからメモリリークが発生するようになり、プロファイルを比較することで原因の関数を特定するなど、アプリケーションの改善に役立ちます。

[http://pyroscope.example.com](http://pyroscope.example.com/) の`Comparison View`から、`Baseline time range`で比較元の期間、`Comparison time range`で比較先の期間を選択すると、比較結果が表示されます。

<img src="./image/grafana-pyroscope-comparison-view.png" width="700">


`Diff View`は上の`Comparison View`を拡張したもので、2つのプロファイルの差分を見ることができます。各関数が費やした時間を比較できるため、たとえばパフォーマンスの劣化や改善を認識できます。

<img src="./image/grafana-pyroscope-diff-view.png" width="700">


## まとめ
当ハンズオンでは、プロファイルとは何かという原理・原則的な話から、実際にGrafanaLabsのPyroscopeを使ったプロファイリングの実装を、手短に説明してみました。プロファイルは、アプリケーションのどのプログラムがパフォーマンスに影響しているかを、一発で見つけることに貢献します。また、メトリクスはもちろん、トレース、ログとの紐付けなども期待できますので、ぜひ実装にチャレンジしてみてください。

## 参考: モノリシックモードで動かす場合
本章はマイクロサービスモードを前提としますが、参考としてモノリシックモードの手順も記載します。

1) `helm/helmfile.yaml` の `values` を一時的にコメントアウトし、`values-micro-services.yaml` を無効化します。
```yaml
releases:
- name: pyroscope
  namespace: monitoring
  createNamespace: true
  chart: grafana/pyroscope
  version: 2.4.3
  # values:
  # - values-micro-services.yaml
```

2) 再デプロイします。
```bash
helmfile sync -f helm/helmfile.yaml
```

3) HTTPRoute のバックエンドServiceを `pyroscope` に変えます（`httproute.yaml`）。
```yaml
    backendRefs:
    # - name: pyroscope-query-frontend # マイクロサービスモードで指定するservice名
    - name: pyroscope # モノリシックモードの場合はこちらに変更
      port: 4040
```

4) Pod例（モノリシック）：
```text
pyroscope-0         1/1     Running   0          22s
pyroscope-alloy-0   2/2     Running   0          22s
```

5) Grafana のデータソースURL例（モノリシック）：
```text
http://pyroscope.monitoring.svc.cluster.local:4040
```

## 参考文献

- [Pyroscopeの公式ドキュメント](https://grafana.com/docs/pyroscope/latest/)
- [What is continuous profiling, and what is Pyroscope?](https://isitobservable.io/open-telemetry/what-is-continuous-profiling-and-what-is-pyroscope)
