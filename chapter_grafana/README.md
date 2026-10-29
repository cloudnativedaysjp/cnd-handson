# Grafana

この章では、Prometheusと併用して使われることが多いGrafanaについて、
ダッシュボードの閲覧・作成から、Git Syncによるダッシュボードのコード管理、Grafana Alertingまでをかんたんに紹介します。

## Grafanaとは

Grafanaとは、メトリクス/ログ/トレースを可視化する基盤として、Prometheusとともによく用いられるOSSです。
組織/ユーザ単位での権限管理や、豊富なプラグインを利用したカスタマイズを行うことができます。

この章で利用するGrafanaは、chapter_prometheusで導入したkube-prometheus-stackに同梱されているものです。
kube-prometheus-stack `92.1.0` には Grafana `13.2.3` が含まれています。

## Datasourceについて

Grafanaでは、さまざまなデータ可視化のソースを利用できます。このソースをDatasourceと呼びます。
公式ドキュメントでは、ビルトインで利用できるDatasourceが紹介されています。
それ以外にも、プラグインを導入して対応させることもできます。

<https://grafana.com/docs/grafana/latest/datasources/#built-in-core-data-sources>

kube-prometheus-stackをインストールした段階では、デフォルトのDatasourceとしてPrometheusとAlertmanagerの設定が入っています。
この章ではPrometheusのDatasourceを使います。

> [!TIP]
> 後半のchapter_loki、chapter_tempo、chapter_pyroscopeでは、ログ・トレース・プロファイルのDatasourceを追加していきます。
> メトリクス以外のデータも同じGrafanaから見られるようになるのがGrafanaの強みです。

## 実践: 標準で用意されているDashboardを見てみる

kube-prometheus-stackではデフォルトで多くのDashboardが用意されており、
基本的なモニタリングをすぐに開始できます。

お使いのブラウザで <http://grafana.example.com/dashboards> にアクセスしてみてください。
ログイン情報はchapter_prometheusで設定したもの(`username: admin, password: handson_saiko!`)です。

主に以下のようなDashboardが用意されています。

- Kubernetes ... クラスタ/Namespace/Pod/Workload単位のCPU・メモリ・ネットワーク使用量、API ServerやKubeletの状態など
- Node Exporter ... ノード単位のCPU・メモリ・ディスク・ネットワークの状態
- Prometheus / Alertmanager / Grafana ... 監視基盤そのものの状態
- Cilium ... chapter_prometheusの`prometheus-values.yaml`で追加したCilium/HubbleのDashboard

試しに `Kubernetes / Compute Resources / Namespace (Pods)` を開き、
画面上部の `namespace` を `handson` に切り替えて、サンプルアプリのリソース使用量を見てみましょう。

<!-- TODO: スクリーンショット(Kubernetes / Compute Resources / Namespace (Pods)) -->

## 実践: ExploreでEnvoy Gatewayのメトリクスを見る

chapter_prometheusでは、PodMonitorを使ってEnvoy Gateway(Envoy Proxy)のメトリクスを収集しました。
ここでは、GrafanaのExploreを使ってそのメトリクスを見てみます。

まずは、サンプルアプリにリクエストを送り続けておきます。
別のターミナルで以下を実行し、この章の間は動かしたままにしておいてください。

```bash
while true; do curl -s -o /dev/null http://app.example.com/; sleep 0.5; done
```

<http://grafana.example.com/explore> にアクセスし、Datasourceが `Prometheus` になっていることを確認します。
クエリエディタを `Code` に切り替えて、以下のPromQLを入力し、 `Run query` をクリックします。

```promql
sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_total[1m]))
```

`envoy_cluster_name` ラベルには、Envoy GatewayがHTTPRouteごとに作るEnvoyのクラスタ名が入っています。
`httproute/<Namespace>/<HTTPRoute名>/rule/<ルール番号>` のような形式になっているので、
`httproute/handson/handson/rule/0` が `app.example.com` へのリクエストに対応します。

<!-- TODO: スクリーンショット(Explore) -->

> [!TIP]
> どんなメトリクスがあるか分からないときは、左メニューの `Drilldown` → `Metrics` を開いてみてください。
> PromQLを書かずに、メトリクス名やラベルで絞り込みながらグラフを眺めることができます。

## 実践: 公開されているDashboardをインポートしてみる

Grafanaでは手作業でDashboardを作成する以外に、
すでに構築されたDashboardの設定をJSONで切り出して保存しておいたものを利用したり、
<https://grafana.com/grafana/dashboards/> 等で提供されているさまざまなダッシュボードをインポートできます。

<https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/import-dashboards/>

ここではEnvoy Gatewayが公式に公開しているDashboardをインポートしてみます。
Envoy GatewayはDashboardをGitHubリポジトリで公開しているので、JSONファイル形式でインポートします。

- <https://github.com/envoyproxy/gateway/tree/v1.9.1/charts/gateway-addons-helm/dashboards>

まずは <http://grafana.example.com/dashboards> にアクセスし、 `New` ボタンのプルダウンメニューから `New folder` をクリックし、
`envoy-gateway` というフォルダ名で作成します。

次に、 `New` ボタンのプルダウンメニューから `Import` をクリックします。

<https://raw.githubusercontent.com/envoyproxy/gateway/v1.9.1/charts/gateway-addons-helm/dashboards/envoy-clusters.json>
を開き、内容をすべてコピーして `Import via dashboard JSON model` の欄に貼り付け、 `Load` をクリックします。

最後に、以下のように設定し、 `Import` をクリックします。

- `Name` ... `Envoy Clusters`
- `Folder` ... `envoy-gateway`

<!-- TODO: スクリーンショット(Import画面) -->

インポートに成功すると、Envoyのクラスタ(HTTPRouteのルール)ごとのリクエスト数やレイテンシが見られるDashboardが表示されます。
画面上部の変数で `httproute/handson/handson/rule/0` を選択してみましょう。

<!-- TODO: スクリーンショット(Envoy Clusters Dashboard) -->

> [!TIP]
> chapter_prometheusの`prometheus-values.yaml`では、`grafana.dashboards`に`gnetId`を指定して、
> grafana.comで公開されているCiliumのDashboardをHelmのインストール時に取り込んでいます。
> このようにDashboardは手作業でのインポート以外に、Helmのvaluesやプロビジョニングの仕組みを使ってコードで管理することもできます。

## Git Syncについて

GUIで作ったDashboardはGrafanaのデータベースに保存されるため、
「誰がいつ何を変えたのか分からない」「別の環境に同じDashboardを作れない」といった問題が起こりがちです。

Git Syncは、GrafanaのDashboardとフォルダをGitリポジトリと同期させる機能です。
Grafana 13からはOSS版でも追加設定なしで利用できます。

<https://grafana.com/docs/grafana/latest/as-code/git-sync/>

Git Syncを使うと、以下のような運用ができるようになります。

- GrafanaのUIで編集したDashboardを、GitリポジトリにcommitしたりPull Requestとして提出したりする
- Gitリポジトリ上でDashboardのJSONを変更すると、Grafana側に反映される
- Dashboardの変更履歴をGitで追いかけ、レビューを経てから反映する

後の章で扱うArgo CDはKubernetesのマニフェストをGitで管理する仕組みですが、
Git SyncはそれのDashboard版と考えるとイメージしやすいでしょう。

> [!NOTE]
> Git Syncで管理できるのはDashboardとフォルダのみです。アラートルールやDatasourceは対象外です。
>
> <https://grafana.com/docs/grafana/latest/as-code/git-sync/usage-limits/>

## 実践: Git SyncでDashboardをGitHubと同期する

> [!NOTE]
> この実践では、ご自身のGitHubアカウントが必要です。
> GitHubアカウントがない場合は、Git Syncの設定をスキップし、
> 後の「Dashboardを作成する」の手順で作るDashboardを通常のフォルダに保存してください。

### GitHubリポジトリとアクセストークンの準備

GitHubで、Dashboardを保存するための新しいリポジトリを作成します。

- `Repository name` ... `grafana-dashboards`(任意)
- `Add README` ... 有効にする(`main`ブランチを作成するため)

次に、Grafanaからリポジトリにアクセスするためのfine-grained personal access tokenを作成します。
GitHubの `Settings` → `Developer settings` → `Personal access tokens` → `Fine-grained tokens` から `Generate new token` をクリックし、以下のように設定します。

- `Repository access` ... `Only select repositories` で、作成した `grafana-dashboards` のみを選択
- `Repository permissions`
  - `Administration` ... `Read-only`
  - `Contents` ... `Read and write`
  - `Metadata` ... `Read-only`
  - `Pull requests` ... `Read and write`
  - `Webhooks` ... `Read and write`

作成したトークンは次の手順で使うので、控えておいてください。

> [!WARNING]
> トークンは対象リポジトリを書き換えられる強い権限を持っています。
> 対象リポジトリを限定し、有効期限を短く設定して、ハンズオン終了後は削除してください。

<https://grafana.com/docs/grafana/latest/as-code/git-sync/git-sync-setup/set-up-before/>

### GrafanaでGit Syncを設定する

<http://grafana.example.com/admin/provisioning> (`Administration` → `General` → `Provisioning`)にアクセスし、
プロバイダとして `GitHub` を選択します。

<!-- TODO: スクリーンショット(Provisioning画面) -->

以下のように設定して、画面に従って進めます。

1. 接続設定
   - 接続方法 ... `Personal Access Token`
   - `Personal Access Token` ... さきほど作成したトークン
   - `Repository URL` ... `https://github.com/<GitHubユーザ名>/grafana-dashboards`
2. リポジトリ設定
   - `Branch` ... `main`
   - `Path` ... `dashboards`
3. 同期する範囲
   - 保存先 ... 新しいフォルダ
   - `Display name` ... `handson-dashboards`
4. その他の設定
   - `Sync interval (seconds)` ... `60`
   - `Read only` ... 無効
   - `Enable pull request option when saving` ... 有効
   - `Enable push to configured branch` ... 有効
   - `Disable webhook integration` ... 有効

最後に `Finish` をクリックすると、Grafanaに `handson-dashboards` フォルダが作成されます。

> [!NOTE]
> Webhookを使うと、GitHub上の変更を即座にGrafanaへ反映できます。
> ただし、GitHubからGrafanaにアクセスできる必要があるため、
> 外部からアクセスできないハンズオン環境ではWebhookを無効にし、一定間隔でのポーリング(ここでは60秒)で同期します。

### Dashboardを作成する

Git Syncで同期している `handson-dashboards` フォルダの中に、サンプルアプリ用のDashboardを作成します。

<http://grafana.example.com/dashboards> で `handson-dashboards` フォルダを開き、 `New` → `New dashboard` をクリックします。

#### Variablesを設定する

DashboardやGrafana Alertingでは、Dashboard Panelやアラートの内容文等に変数を埋め込むことができます。
これはVariablesという仕組みで提供されています。

<https://grafana.com/docs/grafana/latest/dashboards/variables/>

ここでは、Envoyのクラスタ名(= HTTPRouteのルール)を選べる変数を作ります。
Dashboardの `Settings` → `Variables` → `Add variable` をクリックし、以下のように設定します。

- `Variable type` ... `Query`
- `Name` ... `route`
- `Data source` ... `Prometheus`
- `Query type` ... `Label values`
- `Label` ... `envoy_cluster_name`
- `Metric` ... `envoy_cluster_upstream_rq_total`
- `Regex` ... `/^httproute\/.*/`

これで、Dashboardの上部にHTTPRouteのルールを選ぶドロップダウンが表示されます。

#### Panelを追加する

`Add` → `Visualization` からPanelを追加し、以下の3つのPanelを作成します。
いずれもDatasourceは `Prometheus` 、クエリエディタは `Code` を使います。

1. リクエスト数(RPS)
   - `Title` ... `Requests per second`
   - クエリ
     ```promql
     sum(rate(envoy_cluster_upstream_rq_total{envoy_cluster_name="$route"}[1m]))
     ```
2. ステータスコード別のリクエスト数
   - `Title` ... `Requests by status code class`
   - クエリ
     ```promql
     sum by (envoy_response_code_class) (rate(envoy_cluster_upstream_rq_xx{envoy_cluster_name="$route"}[1m]))
     ```
   - `Legend` ... `Custom` で `{{envoy_response_code_class}}xx`
3. p99レイテンシ
   - `Title` ... `p99 latency`
   - クエリ
     ```promql
     histogram_quantile(0.99, sum by (le) (rate(envoy_cluster_upstream_rq_time_bucket{envoy_cluster_name="$route"}[5m])))
     ```
   - `Standard options` → `Unit` ... `Time / milliseconds (ms)`

<!-- TODO: スクリーンショット(作成したDashboard) -->

#### Pull Requestとして保存する

`Save dashboard` をクリックし、以下のように設定します。

- `Title` ... `Handson App`
- 保存方法 ... 新しいブランチを作成してPull Requestを作成する

<!-- TODO: スクリーンショット(Git Syncの保存ダイアログ) -->

保存すると、GitHubの `grafana-dashboards` リポジトリにDashboardのJSONを含むブランチが作成されます。
GitHub上でPull Requestを作成し(Grafanaの画面に表示されるリンクからも開けます)、内容を確認して `main` ブランチにマージしてください。

マージ後、最大60秒ほど待つと、Grafanaの `handson-dashboards` フォルダに `Handson App` Dashboardが反映されます。
すぐに反映したい場合は、 <http://grafana.example.com/admin/provisioning> の `Repositories` タブから対象リポジトリの `Pull` をクリックします。

> [!TIP]
> 同期の状態は、 <http://grafana.example.com/admin/provisioning> の `Repositories` タブで対象リポジトリの `View` をクリックすると確認できます。
> 同期に失敗した場合は、ここにエラーの詳細が表示されます。

### GitHub上の変更をGrafanaに反映する

今度は逆に、GitHub上でDashboardを変更してみます。

GitHubの `grafana-dashboards` リポジトリで `dashboards/` 配下にあるDashboardのJSONファイルを開き、
鉛筆アイコンから編集します。
例えば、 `"title": "Handson App"` を `"title": "Handson App (edited on GitHub)"` に変更し、 `main` ブランチにcommitしてください。

最大60秒ほど待ってからGrafanaの画面をリロードすると、Dashboardのタイトルが変わっていることが確認できます。

このように、Git Syncを使うとDashboardをGitで管理しつつ、GrafanaのUIでの編集体験も損なわずに運用できます。

## 実践: Grafana Alertingを試してみる

最後に、Grafana Alertingを試してみます。
今回は、クラスタ内にWebhookを受け取るだけのアプリをデプロイし、そこにアラートを通知してみましょう。

### 通知先(Webhook受信アプリ)のデプロイ

受け取ったリクエストの内容をログに出力するだけのアプリをデプロイします。

```bash
kubectl apply -f manifests/webhook-receiver.yaml
```

```bash
kubectl get pods -n prometheus -l app=webhook-receiver
```

```bash
# 実行結果
NAME                                READY   STATUS    RESTARTS   AGE
webhook-receiver-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

### Contact Pointの追加

<http://grafana.example.com/alerting/notifications> にアクセスして、
`Create contact point` ボタンをクリックします。

以下のような設定を入力して、 `Test` ボタンをクリックしてテストアラートを発報します。

- `Name` ... `handson-webhook`
- `Integration` ... `Webhook`
- `URL` ... `http://webhook-receiver.prometheus.svc.cluster.local/`

<!-- TODO: スクリーンショット(Contact Point作成画面) -->

Webhook受信アプリのログを確認し、Grafanaから通知が届いていることを確認します。

```bash
kubectl logs -n prometheus -l app=webhook-receiver --tail 50
```

`"receiver": "handson-webhook"` や `"status": "firing"` を含むJSONが出力されていれば成功です。
無事テストが成功したら、 `Save contact point` をクリックして保存します。

> [!TIP]
> Integrationには、Slack、Microsoft Teams、PagerDuty、メールなどさまざまな通知先を指定できます。
> Slackに通知したい場合は、SlackでIncoming Webhook URLを発行し、 `Integration` を `Slack` にして設定してください。
>
> <https://api.slack.com/messaging/webhooks>

### Notification Policyの追加

Contact Pointを追加しただけでは、新規にアラートを追加してもさきほどのContact Pointに向けて発報できません。
それを実現するために、Notification Policyを作成する必要があります。

<http://grafana.example.com/alerting/routes> にアクセスし、 `New child policy` のボタンをクリックします。

以下の設定を入力し、 `Save policy` ボタンをクリックします。

- `Label` ... `alert-route`
- `Operator` ... `=`
- `Value` ... `handson`
- `Contact point` ... `handson-webhook`

<!-- TODO: スクリーンショット(Notification Policy作成画面) -->

### アラートルールの作成

最後に、具体的なアラートルールを作成します。
ここでは、「サンプルアプリへのリクエストが途絶えたら通知する」というルールを作ります。

<http://grafana.example.com/alerting/list> にアクセスし、 `New alert rule` のボタンをクリックします。
以下の内容を設定し、最後に `Save` ボタンをクリックします。

1. Enter alert rule name
   - `Name` ... `HandsonAppNoTraffic`
2. Define query and alert condition
   - Datasource ... `Prometheus`
   - クエリ( `Code` に切り替えて入力)
     ```promql
     sum(rate(envoy_cluster_upstream_rq_total{envoy_cluster_name="httproute/handson/handson/rule/0"}[1m])) or vector(0)
     ```
   - `Alert condition` ... `IS BELOW` `0.5`
3. Add folder and labels
   - `Folder` ... `envoy-gateway`
   - `Labels` ... `alert-route = handson`
4. Set evaluation behavior
   - `Evaluation group` ... 新規作成し、 `Evaluation group name` を `handson-app`、 `Evaluation interval` を `1m` に設定
   - `Pending period` ... `1m`
5. Configure notifications
   - Notification Policyを使って通知先を決める設定にします(手順3で付けたラベルで `handson-webhook` にルーティングされます)
6. Configure notification message
   - `Summary` ... `app.example.com has no traffic`
   - `Description` ... `Requests to app.example.com have been below 0.5 rps for 1 minute.`

<!-- TODO: スクリーンショット(アラートルール作成画面) -->

このアラートは、 `app.example.com` へのリクエスト数が1分間平均で毎秒0.5回を下回った状態が1分続くと発報されるルールになっています。

最初に実行した`curl`のループを `Ctrl+C` で止めて、数分待ってみましょう。
<http://grafana.example.com/alerting/list> でアラートの状態が `Pending` → `Firing` と変わり、
Webhook受信アプリのログに `HandsonAppNoTraffic` の通知が出力されるはずです。

```bash
kubectl logs -n prometheus -l app=webhook-receiver --tail 50
```

再び`curl`のループを実行すると、しばらくしてアラートが解消(`Resolved`)され、その通知も届きます。

> [!TIP]
> 通知に含まれるメッセージはGrafanaの[Notification Templates](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/template-notifications/create-notification-templates/)を利用することで、
> 自由に編集可能です。

## 後片付け

Git Syncの接続を削除する場合は、 <http://grafana.example.com/admin/provisioning> の `Repositories` タブで対象リポジトリの `Settings` → `Delete` をクリックします。
同期済みのDashboardを残すか削除するかを選べます。

ハンズオンが終わったら、GitHubで作成したfine-grained personal access tokenも削除してください。

Webhook受信アプリは以下で削除できます。

```bash
kubectl delete -f manifests/webhook-receiver.yaml
```
