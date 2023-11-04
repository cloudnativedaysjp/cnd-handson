# chapter03_grafana

この章では、Prometheusと併用して使われることが多いGrafanaについて、機能をかんたんに紹介します。

## 実践: kube-prometheus-stackとGrafana

chapter02で導入したkube-prometheus-stackによって、すでにGrafanaは導入されています。
そして、kube-prometheus-stackではデフォルトで多くのダッシュボードが用意されており、
基本的なモニタリングをすぐに開始することができます。

実際にどのようなダッシュボードがあるか見てみましょう。
お使いのブラウザで `grafana.example.com` にアクセスしてみてください。
以下のようなダッシュボードが用意されているはずです。

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

## Datasourceについて

## Variablesについて

## Grafana Alertingについて

## おすすめダッシュボード一覧
