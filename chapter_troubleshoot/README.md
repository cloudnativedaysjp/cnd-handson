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

## 目次

- [前提条件](#前提条件)
- [実施手順](#実施手順)
- [シナリオ1: 環境変数が読み込めずPodが起動しない](#シナリオ1-環境変数が読み込めずpodが起動しない)
- [シナリオ2: Podが何度も再起動を繰り返す](#シナリオ2-podが何度も再起動を繰り返す)
- [シナリオ3: コンテナイメージが取得できない](#シナリオ3-コンテナイメージが取得できない)
- [シナリオ4: PodがPendingのまま起動しない](#シナリオ4-podがpendingのまま起動しない)
- [シナリオ5: Ingressで503エラーが発生する](#シナリオ5-ingressで503エラーが発生する)

---

## シナリオ1: 環境変数が読み込めずPodが起動しない

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
# マニフェストを適用
kubectl apply -f manifests/01-configmap.yaml

# リソースが作成されたことを確認
kubectl get all -n troubleshoot
```

### 症状
- Podが`CreateContainerConfigError`状態になる
- 環境変数が正しく設定されない
- アプリケーションが設定を読み込めずにエラーになる


<details>
<summary>デバッグ方法(参考)</summary>
```bash
# Podの状態を確認
kubectl get pods -n troubleshoot

# Podの詳細を確認（エラーメッセージを確認）
kubectl describe pod <pod-name> -n troubleshoot

# ConfigMapの内容を確認
kubectl get configmap config -n troubleshoot -o yaml

# ConfigMapのキー一覧を確認
kubectl describe configmap config -n troubleshoot

# イベントを確認
kubectl get events -n troubleshoot --sort-by='.lastTimestamp'
```
</details>

---

## シナリオ2: Podが何度も再起動を繰り返す

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
# マニフェストを適用
kubectl apply -f manifests/02-oom.yaml

# リソースが作成されたことを確認
kubectl get all -n troubleshoot
```

### 症状
- Podが繰り返し再起動する
- `kubectl get pods`で`CrashLoopBackOff`や`OOMKilled`が表示される
- アプリケーションが正常に起動しない


<details>
<summary>デバッグ方法(参考)</summary>
```bash
# Podの状態を確認
kubectl get pods -n troubleshoot

# Podの詳細を確認（Stateセクションに"OOMKilled"と表示される）
kubectl describe pod <pod-name> -n troubleshoot

# Podのログを確認
kubectl logs <pod-name> -n troubleshoot --previous

# Podのメトリクスを確認
kubectl top pod -n troubleshoot
```
</details>


---

## シナリオ3: コンテナイメージが取得できない

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
# マニフェストを適用
kubectl apply -f manifests/03-image_pull.yaml

# リソースが作成されたことを確認
kubectl get all -n troubleshoot
```

### 症状
- Podが`ImagePullBackOff`または`ErrImagePull`状態になる
- `kubectl describe pod`で"manifest unknown"や"not found"というエラーが表示される
- 以前は動いていたBitnamiのイメージが突然Pullできなくなる


<details>
<summary>デバッグ方法(参考)</summary>
```bash
# Podの状態を確認
kubectl get pods -n troubleshoot

# Podの詳細を確認（エラーメッセージを確認）
kubectl describe pod <pod-name> -n troubleshoot

# イベントを確認
kubectl get events -n troubleshoot --sort-by='.lastTimestamp'

# ImagePullのログを確認
kubectl logs <pod-name> -n troubleshoot
```
</details>


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


<details>
<summary>デバッグ方法(参考)</summary>
```bash
# Podの状態を確認
kubectl get pods -n troubleshoot

# Podがスケジュールされない理由を確認
kubectl describe pod <pod-name> -n troubleshoot

# NodeのTaintを確認
kubectl describe node <node-name> | grep Taint

# イベントを確認
kubectl get events -n troubleshoot --sort-by='.lastTimestamp'
```
</details>


---

## シナリオ5: Ingressで503エラーが発生する

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
# マニフェストを適用
kubectl apply -f manifests/05-ingress.yaml

# リソースが作成されたことを確認
kubectl get all -n frontend
kubectl get all -n backend
```

### 症状
- frontendネームスペースのIngressから、backendネームスペースのServiceを参照しようとすると失敗する
- `/api`パスにアクセスしても503エラーが返ってくる


<details>
<summary>デバッグ方法(参考)</summary>
```bash
# Ingressの状態を確認
kubectl describe ingress ingress -n frontend

# Ingressのバックエンドを確認
kubectl get ingress ingress -n frontend -o yaml

# イベントを確認
kubectl get events -n frontend --sort-by='.lastTimestamp'
```
</details>
