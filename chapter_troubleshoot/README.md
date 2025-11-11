# トラブルシューティング

## 概要

このチャプターでは、Kubernetesで頻繁に遭遇するトラブルを実際に再現し、デバッグから解決までのプロセスを体験します。
作って壊してを繰り返すことで、実践的なトラブルシューティングの技術を身につけることができます。

各問題の解説は[ANSWER.md](./ANSWER.md)に記載してあります。
マニフェストを修正した例は[manifests_fixed](./manifests_fixed)に記載してあるので参考にしてみてください。
必ずしも修正方法はひとつではなく、ANSWER.mdにもその一例のみ記載してあります。

## 事前準備

本章を始める前に，以下のコマンドで事前にnamespaceを作成してください．

```bash
kubectl create namespace troubleshoot
```

### このチャプターで学べること

- よくあるKubernetesのトラブルパターンとその原因
- 効果的なデバッグコマンドの使い方
- エラーメッセージの読み方と対処方法
- 問題の切り分けと解決のアプローチ

### 対象となるトラブルシナリオ

1. **シナリオ1** - 環境変数が読み込めずPodが起動しない
2. **シナリオ2** - Podが何度も再起動を繰り返す
3. **シナリオ3** - コンテナイメージが取得できない
4. **シナリオ4** - PodがPendingのまま起動しない
5. **シナリオ5** - Ingressで503エラーが発生する
6. **シナリオ6** - 総合問題

> [!NOTE]
> 各シナリオは独立しているため、興味のあるものから始めることができます。
> 初めての方は、シナリオ1から順番に進めることをお勧めします。
> また、各シナリオを開始する前の`troubleshoot`ネームスペースには、リソースが存在しない状態からスタートします。

## 目次

- [トラブルシューティングの勘所とヒント](#トラブルシューティングの勘所とヒント)
- [シナリオ1: 環境変数が読み込めずPodが起動しない](#シナリオ1-環境変数が読み込めずpodが起動しない)
- [シナリオ2: Podが何度も再起動を繰り返す](#シナリオ2-podが何度も再起動を繰り返す)
- [シナリオ3: コンテナイメージが取得できない](#シナリオ3-コンテナイメージが取得できない)
- [シナリオ4: PodがPendingのまま起動しない](#シナリオ4-podがpendingのまま起動しない)
- [シナリオ5: Ingressで503エラーが発生する](#シナリオ5-ingressで503エラーが発生する)
- [シナリオ6: 総合問題](#シナリオ6-総合問題)

---

## トラブルシューティングの勘所とヒント

> [!NOTE]
> **`kubectl top`コマンドについて**
>
> このチャプターでは、リソース使用状況を確認するために`kubectl top pod`や`kubectl top node`コマンドを使用します。これらのコマンドを利用するには、Kubernetesクラスタに[Metrics Server](https://github.com/kubernetes-sigs/metrics-server)がデプロイされている必要があります。
>
> Prometheusの章をまだ実施していない場合は、以下のコマンドでMetrics Serverを導入してください:
> ```bash
> kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
> ```

### よく使う`kubectl`コマンド一覧

- **リソースの確認**:
  - `kubectl get <resource-type> -n <namespace>`: 特定のリソースの情報を取得
  - `kubectl describe <resource-type> <resource-name> -n <namespace>`: リソースの詳細情報を取得
  - `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`: イベントログを確認
- **Podのデバッグ**:
  - `kubectl logs <pod-name> -n <namespace>`: Podのログを表示
  - `kubectl logs <pod-name> -n <namespace> --previous`: 以前のコンテナのログを表示
  - `kubectl exec -it <pod-name> -n <namespace> -- <command>`: Pod内でコマンドを実行
- **リソースの操作**:
  - `kubectl apply -f <file>`: マニフェストを適用
  - `kubectl delete -f <file>`: マニフェストで定義されたリソースを削除
  - `kubectl delete <resource-type> <resource-name> -n <namespace>`: 特定のリソースを削除

### `kubectl`公式ドキュメント

より詳細な情報は、[Kubernetes公式ドキュメント](https://kubernetes.io/docs/reference/kubectl/)を参照してください。

---

## シナリオ1: 環境変数が読み込めずPodが起動しない

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
kubectl apply -f manifests/01-configmap.yaml
```

リソースが作成されたことを確認
```bash
kubectl get all -n troubleshoot
```

### 症状
- Podが`CreateContainerConfigError`状態になる
- 環境変数が正しく設定されない
- アプリケーションが設定を読み込めずにエラーになる

### 正解の状態

以下の状態になれば正解です:

```bash
# Podが Running 状態になっている
kubectl get pods -n troubleshoot
# NAME              READY   STATUS    RESTARTS   AGE
# app-configmap-xxx 1/1     Running   0          1m

# ログに環境変数が正しく出力されている
kubectl logs $(kubectl get pods -n troubleshoot -l app=app-configmap -o jsonpath='{.items[0].metadata.name}') -n troubleshoot
# Starting application...
# DB_HOST: postgres.default.svc.cluster.local
# DB_PORT: 5432
# DB_NAME: myapp
# LOG_LEVEL: info
```

<details>
<summary>デバッグ方法(参考)</summary>

```bash
# Podの状態を確認
kubectl get pods -n troubleshoot

# Podの詳細を確認（エラーメッセージを確認）
kubectl describe pod $(kubectl get pods -n troubleshoot -l app=app-configmap -o jsonpath='{.items[0].metadata.name}') -n troubleshoot

# ConfigMapの内容を確認
kubectl get configmap config -n troubleshoot -o yaml

# ConfigMapのキー一覧を確認
kubectl describe configmap config -n troubleshoot

# イベントを確認
kubectl get events -n troubleshoot --sort-by='.lastTimestamp'
```
</details>

### クリーンアップ

以下のコマンドで、作成したリソースを削除します。

```bash
kubectl delete -f manifests/01-configmap.yaml
```

---

## シナリオ2: Podが何度も再起動を繰り返す

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
kubectl apply -f manifests/02-oom.yaml
```

リソースが作成されたことを確認
```bash
kubectl get all -n troubleshoot
```

### 症状
- Podが繰り返し再起動する
- `kubectl get pods`で`CrashLoopBackOff`や`OOMKilled`が表示される
- アプリケーションが正常に起動しない

### 正解の状態

以下の状態になれば正解です:

```bash
# Podが Running 状態で、再起動回数が 0 になっている
kubectl get pods -n troubleshoot
# NAME           READY   STATUS    RESTARTS   AGE
# app-oom-xxx    1/1     Running   0          2m

# メモリ使用量が制限内に収まっている (Metrics Serverが必要)
kubectl top pod -n troubleshoot
# NAME           CPU(cores)   MEMORY(bytes)
# app-oom-xxx    1m           256Mi
```

<details>
<summary>デバッグ方法(参考)</summary>

```bash
# Podの状態を確認
kubectl get pods -n troubleshoot

# Podの詳細を確認（Stateセクションに"OOMKilled"と表示される）
kubectl describe pod $(kubectl get pods -n troubleshoot -l app=app-oom -o jsonpath='{.items[0].metadata.name}') -n troubleshoot

# Podのメトリクスを確認
kubectl top pod -n troubleshoot
```
</details>

### クリーンアップ

以下のコマンドで、作成したリソースを削除します。

```bash
kubectl delete -f manifests/02-oom.yaml
```


---

## シナリオ3: コンテナイメージが取得できない

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

マニフェストを適用
```bash
kubectl apply -f manifests/03-image_pull.yaml
```

リソースが作成されたことを確認
```bash
kubectl get all -n troubleshoot
```

### 症状
- Podが`ImagePullBackOff`または`ErrImagePull`状態になる
- `kubectl describe pod`で"manifest unknown"や"not found"というエラーが表示される
- 以前は動いていたBitnamiのイメージが突然Pullできなくなる

### 正解の状態

以下の状態になれば正解です:

```bash
# 全てのPodが Running 状態になっている
kubectl get pods -n troubleshoot
# NAME                   READY   STATUS    RESTARTS   AGE
# app-image-pull-xxx-1   1/1     Running   0          1m
# app-image-pull-xxx-2   1/1     Running   0          1m

# イメージが正しくPullされている (nginx:1.27 または bitnami/nginx:latest)
kubectl get pods -n troubleshoot -o jsonpath='{.items[0].spec.containers[0].image}'
# nginx:1.27
```

<details>
<summary>デバッグ方法(参考)</summary>

```bash
# Podの状態を確認
kubectl get pods -n troubleshoot

# Podの詳細を確認（エラーメッセージを確認）
kubectl describe pod $(kubectl get pods -n troubleshoot -l app=app-image-pull -o jsonpath='{.items[0].metadata.name}') -n troubleshoot

# イベントを確認
kubectl get events -n troubleshoot --sort-by='.lastTimestamp'

# ImagePullのログを確認
kubectl logs $(kubectl get pods -n troubleshoot -l app=app-image-pull -o jsonpath='{.items[0].metadata.name}') -n troubleshoot
```
</details>

### クリーンアップ

以下のコマンドで、作成したリソースを削除します。

```bash
kubectl delete -f manifests/03-image_pull.yaml
```

---

## シナリオ4: PodがPendingのまま起動しない

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
# セットアップスクリプトを実行
./scripts/setup-04-scheduling.sh
```

<details>
<summary>手動でセットアップする場合</summary>

```bash
# NodeにTaintを設定（<node-name>は実際のNode名に置き換えてください）
kubectl taint nodes <node-name> workload=batch:NoSchedule

# Taintが設定されたことを確認
kubectl describe node <node-name> | grep Taint

# マニフェストを適用
kubectl apply -f manifests/04-scheduling.yaml

# リソースが作成されたことを確認
kubectl get all -n troubleshoot
```

</details>

### 症状
- Podが`Pending`状態のまま起動しない
- `kubectl describe pod`で"0/X nodes are available"というメッセージが表示される
- SchedulingFailedイベントが記録される

### 正解の状態

以下の状態になれば正解です:

```bash
# Podが Running 状態で、Nodeにスケジュールされている
kubectl get pods -n troubleshoot -o wide
# NAME                 READY   STATUS    RESTARTS   AGE   NODE
# app-scheduling-xxx   1/1     Running   0          1m    <node-name>

# Podのtolerationが正しく設定されている
kubectl get pod $(kubectl get pods -n troubleshoot -l app=app-scheduling -o jsonpath='{.items[0].metadata.name}') -n troubleshoot -o jsonpath='{.spec.tolerations}' | jq
# [
#   {
#     "effect": "NoSchedule",
#     "key": "workload",
#     "operator": "Equal",
#     "value": "batch"
#   }
# ]
```

<details>
<summary>デバッグ方法(参考)</summary>

```bash
# Podの状態を確認
kubectl get pods -n troubleshoot

# Podがスケジュールされない理由を確認
kubectl describe pod $(kubectl get pods -n troubleshoot -l app=app-scheduling -o jsonpath='{.items[0].metadata.name}') -n troubleshoot

# NodeのTaintを確認
kubectl describe node <node-name> | grep Taint

# イベントを確認
kubectl get events -n troubleshoot --sort-by='.lastTimestamp'
```
</details>

### クリーンアップ

以下のコマンドで、作成したリソースを削除します。

```bash
./scripts/setup-04-scheduling.sh --delete
```


---

## シナリオ5: Ingressで503エラーが発生する

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

マニフェストを適用
```bash
kubectl apply -f manifests/05-ingress.yaml
```

### 症状

- `curl`やブラウザでIngressにアクセスすると、503 Service Temporarily Unavailableエラーが返ってくる
- Ingress Controllerのログに、バックエンドのServiceが見つからないというエラーが出力される

### 正解の状態

以下の状態になれば正解です:

```bash
# troubleshoot namespaceにExternalName Serviceが作成されている
kubectl get svc -n troubleshoot
# NAME           TYPE           EXTERNAL-NAME                                 PORT(S)
# frontend-app   ExternalName   app-frontend.frontend.svc.cluster.local       80/TCP
# backend-app    ExternalName   app-backend.backend.svc.cluster.local         8080/TCP

# curlでアクセスできる
curl http://troubleshoot.example.com/
# <!DOCTYPE html>... (nginxのデフォルトページ)

curl http://troubleshoot.example.com/api
# Hello from backend API
```

<details>
<summary>デバッグ方法(参考)</summary>

```bash
# Ingressの状態を確認
kubectl get ingress -n troubleshoot

# Ingressの詳細を確認
kubectl describe ingress ingress -n troubleshoot

# Ingressのバックエンドを確認
kubectl get ingress ingress -n troubleshoot -o yaml

# 各namespaceのServiceを確認
kubectl get svc -n frontend
kubectl get svc -n backend

# イベントを確認
kubectl get events -n troubleshoot --sort-by='.lastTimestamp'

# Ingress Nginx Controllerのログを確認 (Ingress ControllerのPod名を適宜変更)
# kubectl logs $(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}') -n ingress-nginx | grep troubleshoot

# curlで疎通確認
curl -H "Host: troubleshoot.example.com" http://troubleshoot.example.com/
curl -H "Host: troubleshoot.example.com" http://troubleshoot.example.com/api
```
</details>

### クリーンアップ

以下のコマンドで、作成したリソースを削除します。

```bash
kubectl delete -f manifests/05-ingress.yaml
```

---

## シナリオ6: 総合問題

セクションの最後に、簡単なWebアプリケーションを使ったトラブルシュートに挑戦してみましょう。
構成図右下にあるcnd-web-appに接続し、適切なWebページを表示させることがゴールです。

![diagram](./image/cnd-tshoot-diagram.svg)

> [!NOTE]
> - 動作確認は、ブラウザから以下のURLにアクセスすることで行います。
>   - http://cnd-web.example.com


以下のコマンドでアプリのデプロイを行なってください。
```sh
kubectl apply -f manifests/06-cnd-web.yaml
```

### 正解の状態

以下の状態になれば正解です:

```bash
# 全てのPodが Running 状態になっている
kubectl get pods -n troubleshoot
# NAME          READY   STATUS    RESTARTS   AGE
# cnd-web-app   1/1     Running   0          2m
# mysql         1/1     Running   0          2m
# dummy-app     1/1     Running   0          2m

# Serviceが正しく設定されている
kubectl get svc -n troubleshoot
# NAME          TYPE        CLUSTER-IP      PORT(S)
# cnd-web-svc   ClusterIP   10.x.x.x        80/TCP
# mysql-svc     ClusterIP   10.x.x.x        3306/TCP

# curlまたはブラウザでアクセスできる
curl http://cnd-web.example.com
# <!DOCTYPE html>... (nginxのデフォルトページが表示される)
```

動作確認後、リソースを削除します。

```sh
kubectl delete -f manifests/06-cnd-web.yaml
```
