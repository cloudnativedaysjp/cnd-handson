# Pyroscope
この章では、オブザーバビリティの主要シグナルとして注目される、プロファイルについて紹介し、オブザーバビリティのバックエンドとして、GrafanaLabsのPyroscopeを導入します。

## プロファイルについて
**プロファイル**とは、ツールによりプログラム実行時の各種データを収集し、得られたデータの統計的な要約を行うことです。あるいは、そのデータのこともプロファイルと呼びます。また、プロファイルを収集する行為のことを、**プロファイリング**と呼びます。

メトリクスとは異なる概念で、アプリケーションがリソースをどのように消費しているかを断面的に見ることができ、リソース消費の多いプログラムを、即座に特定すること等に役立ちます。

オブザーバビリティにおける主要シグナルとして、ログ、メトリクス、トレースが挙げられ、「3本柱」とも呼ばれがちですが、プロファイルでしか表せない表現もあるため、ぜひ注目してほしい言葉です。

## 従来のプロファイリング（非連続）と継続的プロファイリング
実は、プロファイルは開発者にとって、既に馴染みあるものかもしれません。
Google Chromeから、下記の手順で、プロファイルを取得することができます。

### 実践：従来のプロファイリング（非連続）
1. Chrome DevToolsを開く:
Google Chromeを開き、任意のWebページを表示します。次に、該当ページ上で右クリックし、「検証」を選択します。または、キーボードショートカットでDevToolsを開くこともできます（Windows/LinuxではCtrl+Shift+I、MacではCmd+Opt+I）。
2. Performanceタブを選択:
DevToolsが開いたら、上部のタブから「Performance」（パフォーマンス）タブを選択します。
3. パフォーマンスプロファイリングの開始:
Performanceタブが開いたら、左上の再生ボタン（▶︎）をクリックしてパフォーマンスプロファイリングを開始します。
4. 操作を実行:
プロファイリングを開始したら、何かしらの操作をします。実際には、アプリケーションで性能の問題が発生する可能性が高い操作を実行します。
5. プロファイリングを停止:
操作が終了したら、プロファイリングを停止します。左上の停止ボタン（■）をクリックします。

![image](./image/chrome_profile.png)
* 期待する結果：何かしらのプロファイルが収集され、画面に表示されること

しかし、この従来のプロファイリングは、アプリケーションにオーバヘッドがかかるため、従来のプロファイリングの実行は、開発環境だけに限定された過去もありました。
また、プロファイルを作るためには、アプリケーションの操作について、記録の開始宣言し、停止した後にデータの分析をする仕組みのため、非連続的なプロファイリングしかできません。

このプロファイリングを、運用環境でも実行可能にし、長期間のプロファイルを収集できるようアプローチしたものが、**継続的プロファイリング**です。
継続的プロファイリングでは、オーバヘッドの低いサンプリングを使用して、プロファイルを安全に収集します。そのプロファイルはデータベースに保存するため、後で分析することができます。

継続的プロファイリングを使用すると、分散サービス化しているアプリケーションが、本番環境でどのように動作するかを、全体的に把握することにも役立ちます。


## Pyroscopeについて
<img src="https://private-user-images.githubusercontent.com/662636/263812497-c1fc4055-b33d-4e69-a450-9e7a7b2317bb.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MTQxMjg2NTcsIm5iZiI6MTcxNDEyODM1NywicGF0aCI6Ii82NjI2MzYvMjYzODEyNDk3LWMxZmM0MDU1LWIzM2QtNGU2OS1hNDUwLTllN2E3YjIzMTdiYi5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjQwNDI2JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI0MDQyNlQxMDQ1NTdaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0wYWYxYTI4ZGE1ZGQ5MTAxYmEyNTA0ZDBhZGJjY2YwY2RlNTgzMmU3MTBjZGU2YjVkNzE1ZTdlZDNmNDQ5OGE1JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZhY3Rvcl9pZD0wJmtleV9pZD0wJnJlcG9faWQ9MCJ9.1jVNNk2jSpI3AFUhdqVPhbTHsA1HYqeTw7_5ewocbvA" width="300">

**Pyroscope**は、Grafana Labsにより展開されている、継続的プロファイリングのOSS製品です。

元々、Grafana Phlare というプロジェクトがありましたが、2023/3 に、Grafana LabsがPyroscope社を買収し、Grafana Phlare と Pyroscope が統合され「Grafana Pyroscope」となりました。
2023/9 に v1.0.0 がリリースされています。

## Pyroscopeのアーキテクチャ（サーバー）
Pyroscopeのアーキテクチャを説明します。後述するdistributorやingester等、Pyrocopeのアーキテクチャは、LokiやMimirなどのGrafanaLabsスタックでも用いられるので、知っておくと良いでしょう。

### Write（プロファイルの書き込み）

<img src="https://mermaid.ink/svg/pako:eNqNkT1PwzAQhv9K5C6t1DY0hrT1wIBgZgCJoeng2OfE4MSRfaFUVf47dkoLI9vd896H7_WJCCuBMKKMPYiaO0xeH4o2SXoPbrp7cxrB72fJYnGfSO3R6bJH62LFn3SUdVuBRxi1SzwK1kckbNNxcSk-M-vH5Cqd2XT3XL6DwMQHBPtZpB6PBsZHJUobwyZqq-Zhv_0ANqGU_sSLg5ZYs6z7-m0KS_7bQuakAddwLYMjpziiIFhDAwVhIZSgeG-wIEU7hFIeTn85toIwdD3MSd9JjvCoeeV4Q5jixl_pk9ThmCs0lksI6YngsYv2V8HMMFLYVukq8t6ZgGvEzrM0jfKy0lj35TK4lXot41_Vn9s8zbN8wzMK-ZryO0qlKFfbjcpuV0qub1YZJ8MwfAN3mqSC" width="100">

1. distributorは、ingesterへプロファイルをPushします。
2. ingesterは、受信したプロファイルを、Pyroscopeのデータベースに保存します。プロファイルをすぐに書き込むのでなく、一度ingesterのメモリ領域か、ingesterのディスク領域に保持します。最終的に、全てのプロファイルがディスクに書き込まれ、長期ストレージに追加されます。ingesterはレプリケートされており、デフォルトでは3つのingesterが動いてます。
3. Compactorは、各ingesterからのブロックを1つにマージし、重複部分を削除します。ブロック圧縮により、ストレージ使用率を大幅に削減します。


### Read（プロファイルの読み込み）
<img src="https://mermaid.ink/svg/pako:eNqNkT1PwzAQhv9K5C6t1DQ0gX54YEAwIwFb08G1z4nBiYN9pkRV_jt2gQJi6XZ-7rmTXt-BcCOAUCK12fOaWUyebso2SbwDO948ABNuO0nS9Dp59WD7VFrTIrQiOn_JL8nxGoTXYL8tBfactmorcPifOzQW0ooh7Fl_JMZFx7jx5n73DBw_le0kUoe9hmOARCqt6Uiu5dShNS9AR0VRfNXpXgmsad69_wwZd_YImZIGbMOUCL93iCtKgjU0UBIaSgGSeY0lKdshqMyjeexbTihaD1PiOxHS3CpWWdYQKpl2J3onVAhzgtowAeF5INh38VSVchhWctNKVUXurQ64RuwczbLYnlUKa7-bcdNkTol41_ptvcgW-WLF8gIWy4JdFYXgu_l6JfPLuRTLi3nOyDAMHzzctK0" width="360">

1. Pyroscope上で実行されたクエリはAPIリクエストとして、query-frontendで受け取ります。
2. query-frontendは、query-schedulerに通信しに行きます。query-schedulerはクエリのキューを維持し、各テナントが公平に実行されるようにします。
3. querierは、query-schedulerのキューから、クエリを取得します。
4. querierの参照先は、最近のデータからならingesterから、長期ストレージからならstore-gatewayからデータを取得します。

## Pyroscopeへのプロファイルの送信（クライアント）
プロファイルをPyroscopeに送信する場合、各言語ごとのPyroscope SDKを使うか、Grafana Agentを使うかの2択となります。しかし、2024/04にGrafana Alloyという、OpenTelemetry Collector互換の新たなOSSが発表されました。Grafana Agentは2025年にEOLとなり、Alloyへとプロジェクト移行されます。

当ハンズオンでは、初期構築時にGrafana Agentがインストールされています。

## 実践: Grafana Pyroscopeのインストール
Kubernetesクラスタ上にPyroscopeをインストールします。
ここでは、grafanaのHelm Chartから利用します。

Pyroscopeでは、モノリシックモードと、マイクロサービスモードという、2つのデプロイ方式が選択できます。ここでは、モノリシックモードで動かしてみます。

用意されているhelmfile.yamlおよびvalues.yamlを利用して、 `helmfile sync` を実行し、Pyroscopeをインストールしましょう。

```bash
helmfile sync helmfile.yaml
```

実際に各種サービスが起動しているか確認します。

```bash
kubectl get pods -n pyroscope
```


```bash
# 実行結果
NAME                READY   STATUS    RESTARTS   AGE
pyroscope-0         1/1     Running   0          69s
pyroscope-agent-0   2/2     Running   0          69s
```

## Pyroscopeフロントエンドへのアクセス
Pyoscopeの画面にアクセスします。pyroscopeのserviceをポートフォワードします。

```bash
kubectl --namespace pyroscope port-forward svc/pyroscope 4040:4040
```
[http://localhost:4040](http://localhost:4040)にアクセスしましょう。既に、Pyroscope自身のプロファイルが確認できます。

![image](./image/pyroscope_web.png)


## Grafanaへのデータソース追加


## 番外：マイクロサービスモードで動かしたいとき
マイクロサービスモードで動かしたい場合、helmのvaluesを宣言した状態で、`helmfile sync`を実施してみてください。
マイクロサービスモードでは、ストレージサービスの指定が必要で、ここではMinIOというオブジェクトストレージサーバが採用されます。

ハンズオン用では、[values-micro-services.yaml](https://raw.githubusercontent.com/grafana/pyroscope/main/operations/pyroscope/helm/pyroscope/values-micro-services.yaml)を元に、要求リソースを小さくして作成しています。

```helmfile.yaml
releases:
- name: pyroscope
  namespace: pyroscope
  createNamespace: true
  chart: grafana/pyroscope
  version: 1.5.0
  values:
  - values-micro-services.yaml # マイクロサービスモードを使用する場合使用
```


```bash
# 実行結果
NAME                                         READY   STATUS    RESTARTS   AGE
pyroscope-agent-0                            2/2     Running   0          33s
pyroscope-compactor-0                        1/1     Running   0          33s
pyroscope-compactor-1                        1/1     Running   0          33s
pyroscope-distributor-65cc858cb6-6mjq2       1/1     Running   0          33s
pyroscope-ingester-0                         1/1     Running   0          33s
pyroscope-ingester-1                         1/1     Running   0          33s
pyroscope-minio-0                            0/1     Pending   0          33s
pyroscope-minio-make-bucket-job-vlmhb        1/1     Running   0          33s
pyroscope-querier-85855c9c5d-88dkj           1/1     Running   0          33s
pyroscope-querier-85855c9c5d-cggfp           1/1     Running   0          33s
pyroscope-querier-85855c9c5d-mt99w           1/1     Running   0          33s
pyroscope-query-frontend-7b55fbf7f6-2cz8p    1/1     Running   0          33s
pyroscope-query-scheduler-7497dd4996-v56z7   1/1     Running   0          33s
pyroscope-store-gateway-0                    0/1     Running   0          33s
pyroscope-store-gateway-1                    0/1     Running   0          33s

```

## 参考文献


- [Pyroscopeの公式ドキュメント](https://grafana.com/docs/pyroscope/latest/)
- [What is continuous profiling, and what is Pyroscope?](https://isitobservable.io/open-telemetry/what-is-continuous-profiling-and-what-is-pyroscope)
