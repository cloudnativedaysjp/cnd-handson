# トラブルシューティング

## 概要

このチャプターでは、Kubernetesで頻繁に遭遇するトラブルを実際に再現し、デバッグから解決までのプロセスを体験します。
作って壊してを繰り返すことで、実践的なトラブルシューティングの技術を身につけることができます。

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

### 一般的なデバッグのヒント

- **リソース名の重複**: `Deployment`や`Service`などのリソース名が重複していると、意図しない挙動を引き起こすことがあります。特に異なるNamespaceで同じ名前を使用している場合、混乱を招きやすいです。リソース名は一意になるように命名規則を設けることを推奨します。
- **Prometheusとの連携**: Prometheusなどのモニタリングツールを導入している環境では、過去のリソース使用状況やイベント履歴を詳細に確認でき、デバッグが格段に容易になります。特に断続的に発生する問題の特定に役立ちます。
- **`kubelet`ログの確認**: Podの起動やコンテナの実行に関する低レベルな問題は、Node上の`kubelet`のログに記録されていることが多いです。`journalctl -u kubelet`などで確認できます。
- **Kubernetes History Inspector**: クラスターのログを視覚化し、問題の履歴を追跡するのに役立つツールです。詳細はこちらを参照してください: [Kubernetes History Inspector](https://cloud.google.com/blog/ja/products/containers-kubernetes/kubernetes-history-inspector-visualizes-cluster-logs)
- **`kubectl apply -n`の注意点**: `Namespace`や`ClusterRole`のようなクラスターレベルのリソースに対して`kubectl apply -f <file> -n <namespace>`を実行しても、`-n`オプションは無視されます。Namespaceを指定する必要があるのは、PodやDeploymentのようなNamespaceスコープのリソースに対してのみです。
- **`kubectl get all`の活用**: `kubectl get all -n <namespace>`は、指定したNamespace内の主要なリソース（Pod, Deployment, Service, ReplicaSetなど）を一覧表示するのに便利です。Ingressリソースはデフォルトでは含まれないため、`kubectl get ingress -n <namespace>`を別途実行する必要があります。

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

### チェックスクリプトの使い方

各シナリオには、現在の状態を確認して適切なヒントを表示するチェックスクリプトが用意されています。

```bash
# シナリオ1のチェック
./scripts/check-01.sh

# シナリオ2のチェック
./scripts/check-02.sh

# シナリオ3のチェック
./scripts/check-03.sh

# シナリオ4のチェック
./scripts/check-04.sh

# シナリオ5のチェック
./scripts/check-05.sh

# シナリオ6のチェック
./scripts/check-06.sh
```

チェックスクリプトは以下を行います:
- リソースの状態を確認
- 問題が解決されていれば「✅ 正解！」と表示
- 問題が残っている場合、現在の状態に応じた具体的なヒントを表示

---

## シナリオ1: 環境変数が読み込めずPodが起動しない

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
kubectl apply -f manifests/01-configmap.yaml
```

```bash
# リソースが作成されたことを確認
kubectl get all -n troubleshoot
```

### 症状
- Podが`CreateContainerConfigError`状態になる
- 環境変数が正しく設定されない
- アプリケーションが設定を読み込めずにエラーになる

### 状態確認とヒント

チェックスクリプトを実行すると、現在の状態を確認してヒントを得られます:

```bash
./scripts/check-01.sh
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

```bash
# リソースが作成されたことを確認
kubectl get all -n troubleshoot
```

### 症状
- Podが繰り返し再起動する
- `kubectl get pods`で`CrashLoopBackOff`や`OOMKilled`が表示される
- アプリケーションが正常に起動しない

### 状態確認とヒント

チェックスクリプトを実行すると、現在の状態を確認してヒントを得られます:

```bash
./scripts/check-02.sh
```

<details>
<summary>デバッグ方法(参考)</summary>

```bash
# Podの状態を確認
kubectl get pods -n troubleshoot

# Podの詳細を確認（Stateセクションに"OOMKilled"と表示される）
kubectl describe pod $(kubectl get pods -n troubleshoot -l app=app-oom -o jsonpath='{.items[0].metadata.name}') -n troubleshoot

# Podのログを確認
kubectl logs $(kubectl get pods -n troubleshoot -l app=app-oom -o jsonpath='{.items[0].metadata.name}') -n troubleshoot --previous

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

```bash
# マニフェストを適用
kubectl apply -f manifests/03-image_pull.yaml
```

```bash
# リソースが作成されたことを確認
kubectl get all -n troubleshoot
```

### 症状
- Podが`ImagePullBackOff`または`ErrImagePull`状態になる
- `kubectl describe pod`で"manifest unknown"や"not found"というエラーが表示される
- 以前は動いていたBitnamiのイメージが突然Pullできなくなる

### 状態確認とヒント

チェックスクリプトを実行すると、現在の状態を確認してヒントを得られます:

```bash
./scripts/check-03.sh
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

### 状態確認とヒント

チェックスクリプトを実行すると、現在の状態を確認してヒントを得られます:

```bash
./scripts/check-04.sh
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

```bash
# マニフェストを適用
kubectl apply -f manifests/05-ingress.yaml
```

次に、Ingressにアクセスするために、以下の行を`/etc/hosts`ファイルに追加します。`<ingress-ip>`はご自身の環境のIngressのIPアドレスに置き換えてください。

```
<ingress-ip> troubleshoot.example.com
```

### 症状

- `curl`やブラウザでIngressにアクセスすると、503 Service Temporarily Unavailableエラーが返ってくる
- Ingress Controllerのログに、バックエンドのServiceが見つからないというエラーが出力される

### 状態確認とヒント

チェックスクリプトを実行すると、現在の状態を確認してヒントを得られます:

```bash
./scripts/check-05.sh
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
kubectl get svc -A | grep -E "troubleshoot|frontend|backend"

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
> - Ingressにアクセスするために、以下の行を`/etc/hosts`ファイルに追加します。`<ingress-ip>`はご自身の環境のIngressのIPアドレスに置き換えてください。
>   - `<ingress-ip> cnd-web.example.com`
> - リソースの更新後もWeb画面の表示が変わらない場合があります。1-2分待ってからブラウザのリフレッシュを行なってください。
> - 改修箇所は1箇所ではない可能性があります。また、構成図とエラーメッセージがヒントになる場合があります。


以下のコマンドでアプリのデプロイを行なってください。
```sh
kubectl apply -f manifests/06-cnd-web.yaml
```

### 状態確認とヒント

チェックスクリプトを実行すると、現在の状態を確認してヒントを得られます:

```bash
./scripts/check-06.sh
```

動作確認後、リソースを削除します。

```sh
kubectl delete -f manifests/06-cnd-web.yaml
```
