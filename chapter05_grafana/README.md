# Grafana

この章では、Prometheusと併用して使われることが多いGrafanaについて、機能をかんたんに紹介します。

## Grafanaとは

Grafanaとは、メトリクス/ログ/トレースを可視化する基盤として、Prometheusとともによく用いられるOSSです。
組織/ユーザ単位での権限管理や、豊富なプラグインを利用したカスタマイズを行うことができます。

## 実践: kube-prometheus-stackとGrafana

chapter02で導入したkube-prometheus-stackによって、すでにGrafanaは導入されています。
そして、kube-prometheus-stackではデフォルトで多くのDashboardが用意されており、
基本的なモニタリングをすぐに開始することができます。

実際にどのようなDashboardがあるか見てみましょう。
お使いのブラウザで <http://grafana.example.com/dashboards> にアクセスしてみてください。
以下のようなDashboardが用意されているはずです。

- AlertManager Overview ... AlertManagerに関する基本的な情報
- CoreDNS ... CoreDNSのDNSレコード別リクエスト/レスポンス数、キャッシュヒット率など
- Grafana Overview ... Grafanaに関する情報(ダッシュボード数や発火中のアラート数など)
- etcd
- Prometheus
  - Overview
- Node Exporter
  - MacOS
  - Nodes
  - USE Method
    - Cluster
    - Node
- Kubernetes
  - API Server ... kube-apiserverに関する基本的なメトリクス(可用性やgoroutine等のメトリクス)
  - Controller Manager
  - Kubelet
  - Persistent Volumes
  - Proxy
  - Scheduler
  - Compute Resources
    - Multi-Cluster
    - Cluster
    - Namespace(Pods)
    - Namespace(Workloads)
    - Node(Pods)
    - Pod
    - Workload
  - Networking
    - Cluster
    - Namespace(Pods)
    - Namespace(Workloads)
    - Pod
    - Workload

## 実践: ハンズオンで利用するDashboardをインポートしてみる

Grafanaでは手作業でDashboardを作成する以外に、
すでに構築されたDashboardの設定をJSONで切り出して保存しておいたものを利用したり、
<https://grafana.com/grafana/dashboards/> 等で提供されている様々なダッシュボードをインポートしたりできます。

<https://grafana.com/docs/grafana/latest/dashboards/manage-dashboards/#import-a-dashboard>

実際にハンズオンでインストールするツールに関するDashboardをインポートしてみましょう。
以下のようなDashboardがありますが、ここではIngress NGINX ControllerのDashboardを導入してみます。

- <https://github.com/kubernetes/ingress-nginx/tree/main/deploy/grafana/dashboards>
- <https://grafana.com/grafana/dashboards/7645-istio-control-plane-dashboard/>
- <https://grafana.com/grafana/dashboards/14584-argocd/>
- <https://grafana.com/grafana/dashboards/16611-cilium-metrics/>
- <https://grafana.com/grafana/dashboards/13539-hubble/>

まずは <http://grafana.example.com/dashboards> にアクセスし、 `New` ボタンのプルダウンメニューから `New folder` をクリックし、
`ingress-nginx` というフォルダ名で作成します。

![image](./image/dashboards.png)

次に、<http://grafana.example.com/dashboards> にもう一度アクセスし、 `New` ボタンのプルダウンメニューから `Import` をクリックします。

その後Dashboardのインポート形式を選択してインポートしますが、
Ingress NGINX Controllerはgrafana.comではなくGitHubでダッシュボードを公開しているので、JSONファイル形式で行います。

<https://github.com/kubernetes/ingress-nginx/blob/main/deploy/grafana/dashboards/nginx.json> を手元にダウンロードしておきます。
Grafana画面で `Upload dashboard JSON file` ボタンをクリックして、
先程ダウンロードしたJSONファイルをアップロードします。

最後に、以下のような画面に遷移するので、次のように設定し、 `Import` をクリックします。

- `Name` ... `NGINX Ingress controller`
- `Folder` ... `ingress-nginx`
- `Prometheus Datasource` ... `Prometheus`

![image](./image/import-dashboard.png)

インポートに成功すると、以下のようなダッシュボードが表示されるはずです。

![image](./image/ingress-nginx.png)

## Datasourceについて

Grafanaでは、様々なデータ可視化のソースを利用することができます。このソースをDatasourceと呼びます。
公式ドキュメントでは、ビルトインで利用できるDatasourceが紹介されています。
それ以外にも、自分でプラグインを書いて対応させることもできます。

<https://grafana.com/docs/grafana/latest/datasources/#built-in-core-data-sources>

kube-prometheus-stackをインストールした段階では、デフォルトのDatasourceとしてPrometheusとAlertmanagerの設定が入っています。
これにより、 <http://grafana.example.com/explore> でPromQLを書きこんでメトリクスを表示したり、
Datasourceから読み取れるメトリクスからDashboardを構築することができます。

## Variablesについて

DashboardやGrafana Alertingでは、Dashboard Panelやアラートの内容文等に変数を埋め込むことができます。
これはVariablesという仕組みで提供されています。

<https://grafana.com/docs/grafana/latest/dashboards/variables>

## 実践: Grafana Alertingを試してみる

実際にGrafana Alertingを試してみます。
今回は、Slack Workspaceの特定channelにアラートを流してみましょう。

### Contact Pointの追加

**2023/12/8に実施されているハンズオンに参加される方はこのステップは不要です。**

まずは、Slackに通知するためにWebhook URLを発行します。
<https://api.slack.com/start/quickstart> にアクセスして、 ドキュメント通りにIncoming Webhook URLを取得します。

1. `1. Creating an app` にある `Go to Your Apps` をクリックする
2. `Create an App` をクリックし、 `From scratch` を選択する
3. アプリ名を `cndt2023-sample-grafana-alert`, ワークスペースを設定し `Create App` をクリックする
4. `Add features and functionality` にある `Incoming Webhooks` をクリックする
5. `Activate Incoming Webhooks` を有効にする
6. `Add New Webhook to Workspace` をクリックする
7. アラートを流すチャンネルを選択し、 `Allow` をクリックする
8. `Webhook URL` をコピーする

Grafana側では <http://grafana.example.com/alerting/notifications> にアクセスして、
右側の `Add contact point` ボタンをクリックします。

![image](./image/notifications.png)

画面が遷移したら、以下のような設定を入力して、 `Test` ボタンをクリックしてテストアラートを発報します。

- `Name` ... `sample-grafana-alerting`
- `Integration` ... `Slack`
- `Webhook URL` ... 先程コピーしたSlack AppのWebhook URL

![image](./image/create-contact-point.png)

成功すると、以下のようなアラートが発報されるはずです。

![image](./image/sample-alert1.png)

無事テストが成功したら、 `Save contact point` をクリックして保存します。

### Notification Policyの追加

Contact Pointを追加しただけでは新規にアラートを追加しても、先程のContact Pointに向けて発報できません。
それを実現するために、Notification Policyを作成する必要があります。

<http://grafana.example.com/alerting/routes> にアクセスし、 `New nested policy` のボタンをクリックします。
以下の設定を入力し、 `Save policy` ボタンをクリックします。

- `Matching Labels` ... `alert-route = slack`
- `Contact point` ... `sample-grafana-alerting`

### サンプルアラートの作成

最後に、具体的なアラートの作成を行います。
<http://grafana.example.com/alerting/list> にアクセスし、 `New alert rule` のボタンをクリックします。
以下の内容で設定し、右上の `Save rule` ボタンをクリックします。

- `Rule name` ... `SampleGrafanaAlert1`
- `Metric` ... `nginx_ingress_controller_requests`
- `Label filter` ... `host = app.example.com`
- `Operation` ... 以下を順に設定
  - `Range Functions > Avg over time` をクリックし、 `Range` を `1m` に設定
  - `Binary Operations > Less than` をクリックし、 `Value` を `10` に設定
- `Summary` ... `app.example.com has not received requests over 10 times`
- `Description` ... `app.example.com has not received {{ $labels.method }} requests 10 times`
- `Custom Labels` ... `alert-route = slack`
- `Folder` ... `ingress-nginx`
- `Evaluation group` ... `New evaluation group` をクリックし、 `Evaluation group name` を `sample-grafana-alert-1`, `Evaluation Interval` を `5m` に設定

このアラートは、1分間隔で取得した、 `app.example.com` に対するリクエスト数が10以上でなければアラートを発報するというルールになっています。
5分程度経過すると、無事にアラートが発報されると思います。
