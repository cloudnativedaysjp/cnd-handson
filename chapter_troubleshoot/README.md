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

1. **ConfigMapの設定ミス** - 環境変数が正しく設定されない
2. **OOM Kill** - メモリ不足でPodが強制終了される
3. **ImagePullBackOff** - コンテナイメージが取得できない
4. **スケジューリング失敗** - Podが適切なNodeに配置されない
5. **Ingress接続失敗** - 外部からサービスにアクセスできない

> [!NOTE]
> 各シナリオは独立しているため、興味のあるものから始めることができます。
> 初めての方は、シナリオ1から順番に進めることをお勧めします。

## 目次

- [前提条件](#前提条件)
- [実施手順](#実施手順)
- [1. ConfigMapの設定が間違ってる](#1-configmapの設定が間違ってる)
- [2. Podが起動しない（OOM Kill）](#2-podが起動しない)
- [3. Imageが Pullできない（Bitnami問題）](#3-imageがpullできない)
- [4. Podがスケジュールされない（Toleration）](#4-podがスケジュールされない)
- [5. Ingressが繋がらない（クロスNamespace）](#5-ingressが繋がらない)
- [Tips: よく使うデバッグコマンド](#tips)
- [まとめ](#まとめ)

---

## 1. ConfigMapの設定が間違ってる

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
# マニフェストを適用
kubectl apply -f manifests/01-configmap.yaml

# リソースが作成されたことを確認
kubectl get all -n configmap-demo
```

<details>
<summary>🔍 問題の詳細を見る</summary>

#### 症状
- Podが`CreateContainerConfigError`状態になる
- 環境変数が正しく設定されない
- アプリケーションが設定を読み込めずにエラーになる

#### デバッグ方法
```bash
# Podの状態を確認
kubectl get pods -n configmap-demo

# Podの詳細を確認（エラーメッセージを確認）
kubectl describe pod <pod-name> -n configmap-demo

# ConfigMapの内容を確認
kubectl get configmap app-config -n configmap-demo -o yaml

# ConfigMapのキー一覧を確認
kubectl describe configmap app-config -n configmap-demo

# イベントを確認
kubectl get events -n configmap-demo --sort-by='.lastTimestamp'
```

</details>

<details>
<summary>✅ 解決方法を見る</summary>

#### 原因
ConfigMapを環境変数として参照する際、以下のいずれかの問題が発生しています:
1. ConfigMapのキー名が実際のキー名と一致していない
2. ConfigMapの名前が間違っている
3. ConfigMapが存在しないnamespaceを参照している

#### 解決策
ConfigMapのキー名とConfigMap名を正しく修正します。

**修正内容**:
```yaml
env:
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: database_host  # db_host → database_host に修正

- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: app-config  # application-config → app-config に修正
      key: log_level
```

**デバッグのコツ**:
1. まずConfigMapが存在することを確認
2. ConfigMapのキー一覧を確認して、正しいキー名を特定
3. Podのdescribeでどのキーが見つからないかを確認

**確認方法**:
```bash
# マニフェストを適用
kubectl apply -f manifests/01-configmap.yaml

# Podの状態を確認（問題が発生しているはず）
kubectl get pods -n configmap-demo
kubectl describe pod <pod-name> -n configmap-demo

# マニフェストを修正して再適用
# 修正内容: key: db_host → database_host, name: application-config → app-config
kubectl apply -f manifests/01-configmap.yaml

# Podが正常に起動していることを確認
kubectl get pods -n configmap-demo

# 環境変数が正しく設定されているか確認
kubectl logs <pod-name> -n configmap-demo | grep -E "DB_HOST|LOG_LEVEL"
```

</details>

---

## 2. Podが起動しない！

**問題**: メモリのlimit設定が不適切でPodがOOM Killされる

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
# マニフェストを適用
kubectl apply -f manifests/02-oom.yaml

# リソースが作成されたことを確認
kubectl get all -n oom-demo
```

<details>
<summary>🔍 問題の詳細を見る</summary>

#### 症状
- Podが繰り返し再起動する
- `kubectl get pods`で`CrashLoopBackOff`や`OOMKilled`が表示される
- アプリケーションが正常に起動しない

#### デバッグ方法
```bash
# Podの状態を確認
kubectl get pods -n oom-demo

# Podの詳細を確認（Stateセクションに"OOMKilled"と表示される）
kubectl describe pod <pod-name> -n oom-demo

# Podのログを確認
kubectl logs <pod-name> -n oom-demo --previous

# Podのメトリクスを確認
kubectl top pod -n oom-demo
```

</details>

<details>
<summary>✅ 解決方法を見る</summary>

#### 原因
アプリケーションが必要とするメモリよりも、resourcesのlimitsで設定されたメモリが少ないため、OOM (Out Of Memory) Killerによってコンテナが強制終了されます。

#### 解決策
アプリケーションが必要とするメモリに応じて、適切なresources limitsを設定します。

**修正内容**:
```yaml
resources:
  requests:
    memory: "256Mi"  # リクエストも増やす
    cpu: "100m"
  limits:
    memory: "512Mi"  # 128Mi → 512Miに変更
    cpu: "200m"
```

**ポイント**:
- アプリケーションの実際のメモリ使用量を`kubectl top pod`で確認
- limitsはピーク時のメモリ使用量 + バッファを考慮して設定
- requestsはベースラインのメモリ使用量を設定

**確認方法**:
```bash
# マニフェストを適用
kubectl apply -f manifests/02-oom.yaml

# Podの状態を確認（OOMKilledで再起動を繰り返すはず）
kubectl get pods -n oom-demo
kubectl describe pod <pod-name> -n oom-demo

# マニフェストを修正して再適用
# 修正内容: memory limits: 128Mi → 512Mi, requests: 64Mi → 256Mi
kubectl apply -f manifests/02-oom.yaml

# Podが正常に起動していることを確認
kubectl get pods -n oom-demo

# メモリ使用量を確認
kubectl top pod -n oom-demo
```

</details>

---

## 3. ImageがPullできない！

**問題**: コンテナイメージのPullに失敗してPodが起動しない（Bitnamiのタグ削除問題）

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
# マニフェストを適用
kubectl apply -f manifests/03-image_pull.yaml

# リソースが作成されたことを確認
kubectl get all -n imagepull-demo
```

<details>
<summary>🔍 問題の詳細を見る</summary>

#### 症状
- Podが`ImagePullBackOff`または`ErrImagePull`状態になる
- `kubectl describe pod`で"manifest unknown"や"not found"というエラーが表示される
- 以前は動いていたBitnamiのイメージが突然Pullできなくなる

#### デバッグ方法
```bash
# Podの状態を確認
kubectl get pods -n imagepull-demo

# Podの詳細を確認（エラーメッセージを確認）
kubectl describe pod <pod-name> -n imagepull-demo

# イベントを確認
kubectl get events -n imagepull-demo --sort-by='.lastTimestamp'

# ImagePullのログを確認
kubectl logs <pod-name> -n imagepull-demo
```

</details>

<details>
<summary>✅ 解決方法を見る</summary>

#### 原因
Bitnamiは2024年頃からイメージのタグ付けポリシーを変更し、特定バージョンのタグを削除する方針になりました。最新版のみを`latest`タグで提供するため、以前使えていた特定バージョン（例：`bitnami/nginx:1.25.0`）のタグが突然削除され、イメージがPullできなくなります。

**参考**: [Bitnamiコンテナイメージがpullできない問題 - Qiita](https://qiita.com/m-masataka/items/73383c77cf2e2b8592f0)

#### 解決策

**解決策1: latestタグを使用する（Bitnamiイメージを使い続ける場合）**

特定バージョンを指定せず、`latest`タグまたはタグなしで使用します。

```yaml
containers:
- name: nginx
  image: bitnami/nginx:latest  # または bitnami/nginx
  ports:
  - containerPort: 8080
```

**注意点**: `latest`タグは予告なくバージョンが変わるため、本番環境では推奨されません。

**解決策2: 公式イメージを使用する（推奨）**

Bitnamiイメージに依存せず、Docker Hub公式のイメージを使用します。

```yaml
containers:
- name: nginx
  image: nginx:1.27  # 特定バージョンを指定可能
  ports:
  - containerPort: 80
```

**解決策3: プライベートレジストリにコピーする**

必要なBitnamiイメージをECR、GCR、ACRなどのプライベートレジストリにコピーして管理します。これにより、タグ削除の影響を受けません。

**確認方法**:
```bash
# マニフェストを適用
kubectl apply -f manifests/03-image_pull.yaml

# Podの状態を確認（ImagePullBackOffになるはず）
kubectl get pods -n imagepull-demo
kubectl describe pod <pod-name> -n imagepull-demo

# マニフェストを修正して再適用
# 解決策1: image: bitnami/nginx:1.25.0 → bitnami/nginx:latest
# 解決策2: image: bitnami/nginx:1.25.0 → nginx:1.27 (推奨)
kubectl apply -f manifests/03-image_pull.yaml

# Podが正常に起動していることを確認
kubectl get pods -n imagepull-demo

# イメージがPullされたことを確認
kubectl describe pod <pod-name> -n imagepull-demo | grep -A10 Events

# 使用しているイメージを確認
kubectl get pod <pod-name> -n imagepull-demo -o jsonpath='{.spec.containers[0].image}'
```

</details>

---

## 4. Podがスケジュールされない！

**問題**: tolerationsの設定ミスでPodがスケジュールされない

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
# NodeにTaintを設定（<node-name>は実際のNode名に置き換えてください）
kubectl taint nodes <node-name> workload=batch:NoSchedule

# Taintが設定されたことを確認
kubectl describe node <node-name> | grep Taint

# マニフェストを適用
kubectl apply -f manifests/04-scheduling.yaml

# リソースが作成されたことを確認
kubectl get all -n scheduling-demo
```

<details>
<summary>🔍 問題の詳細を見る</summary>

#### 症状
- Podが`Pending`状態のまま起動しない
- `kubectl describe pod`で"0/X nodes are available"というメッセージが表示される
- SchedulingFailedイベントが記録される

#### デバッグ方法
```bash
# Podの状態を確認
kubectl get pods -n scheduling-demo

# Podがスケジュールされない理由を確認
kubectl describe pod <pod-name> -n scheduling-demo

# NodeのTaintを確認
kubectl describe node <node-name> | grep Taint

# イベントを確認
kubectl get events -n scheduling-demo --sort-by='.lastTimestamp'
```

</details>

<details>
<summary>✅ 解決方法を見る</summary>

#### 原因
NodeにはTaintが設定されており、PodにはそれをTolerate（許容）するTolerationが必要です。しかし、Tolerationの`effect`が間違っているため、PodがNodeにスケジュールされません。

**Taintとは**:
- Nodeに「特定の条件を満たすPodのみをスケジュールする」という制約を設定する機能
- 例: `workload=batch:NoSchedule` は「workload=batchをTolerateするPodのみをスケジュールする」という意味

**Tolerationとは**:
- PodがNodeのTaintを許容するための設定
- key、value、effectがNodeのTaintと完全に一致する必要がある

#### 解決策
NodeのTaintとPodのTolerationのeffectを一致させます。

**事前準備** (Nodeにtaintを設定):
```bash
# 検証用にNodeにtaintを設定
kubectl taint nodes <node-name> workload=batch:NoSchedule

# taintが設定されたことを確認
kubectl describe node <node-name> | grep Taint
```

**修正内容**:
```yaml
tolerations:
- key: "workload"
  operator: "Equal"
  value: "batch"
  effect: "NoSchedule"  # NoExecute → NoScheduleに修正
```

**effectの種類**:
- `NoSchedule`: 新しいPodをスケジュールしない
- `NoExecute`: 既存のPodも退避させる
- `PreferNoSchedule`: 可能な限りスケジュールしない（ソフト制約）

**確認方法**:
```bash
# マニフェストを適用
kubectl apply -f manifests/04-scheduling.yaml

# Podの状態を確認（Pendingのままのはず）
kubectl get pods -n scheduling-demo
kubectl describe pod <pod-name> -n scheduling-demo

# マニフェストを修正して再適用
# 修正内容: effect: "NoExecute" → "NoSchedule"
kubectl apply -f manifests/04-scheduling.yaml

# Podが正常にスケジュールされることを確認
kubectl get pods -n scheduling-demo

# どのNodeにスケジュールされたか確認
kubectl get pods -n scheduling-demo -o wide
```

**後片付け**:
```bash
# taintを削除
kubectl taint nodes <node-name> workload=batch:NoSchedule-
```

</details>

---

## 5. Ingressが繋がらない！

**問題**: Ingressがnamespaceを跨いで別のnamespaceのServiceに接続できない

### 環境構築

まず、問題を再現するためのリソースをデプロイします。

```bash
# マニフェストを適用
kubectl apply -f manifests/05-ingress.yaml

# リソースが作成されたことを確認
kubectl get all -n frontend
kubectl get all -n backend
```

<details>
<summary>🔍 問題の詳細を見る</summary>

#### 症状
- frontendネームスペースのIngressから、backendネームスペースのServiceを参照しようとすると失敗する
- `/api`パスにアクセスしても503エラーが返ってくる

#### デバッグ方法
```bash
# Ingressの状態を確認
kubectl describe ingress app-ingress -n frontend

# Ingressのバックエンドを確認
kubectl get ingress app-ingress -n frontend -o yaml

# イベントを確認
kubectl get events -n frontend --sort-by='.lastTimestamp'
```

</details>

<details>
<summary>✅ 解決方法を見る</summary>

#### 原因
Kubernetesでは、Ingressは同じnamespace内のServiceしか直接参照できません。異なるnamespaceのServiceを参照しようとすると、Serviceが見つからずエラーになります。

#### 解決策
ExternalName Serviceを使用して、異なるnamespaceのServiceを参照できるようにします。

**手順**:
1. frontendネームスペース内に、backendネームスペースのServiceを指すExternalName Serviceを作成
2. Ingressからはfrontendネームスペース内のExternalName Serviceを参照

**修正内容**:
```yaml
# frontendネームスペース内にExternalName Serviceを作成
apiVersion: v1
kind: Service
metadata:
  name: backend-proxy
  namespace: frontend
spec:
  type: ExternalName
  externalName: backend-service.backend.svc.cluster.local
  ports:
  - port: 8080
```

**確認方法**:
```bash
# マニフェストを適用
kubectl apply -f manifests/05-ingress.yaml

# Ingressの状態を確認（backend-serviceが見つからないエラー）
kubectl get ingress -n frontend
kubectl describe ingress app-ingress -n frontend

# マニフェストを修正して再適用
# 修正内容: frontendネームスペース内にExternalName Serviceを追加
# 詳細は上記の「修正内容」セクションを参照
kubectl apply -f manifests/05-ingress.yaml

# Ingressが正しく動作しているか確認
kubectl get ingress -n frontend

# curlで疎通確認
curl -H "Host: troubleshoot.example.com" http://<ingress-ip>/api
```

</details>

---

## 前提条件

- Kubernetesクラスターが稼働していること
- `kubectl`コマンドが使用可能であること
- Ingress Controllerがインストールされていること（シナリオ5の場合）

## 実施手順

各トラブルシューティングシナリオは以下の流れで進めます。

### 基本的な流れ

1. **問題を再現する**

   用意されたマニフェストファイルをapplyして、問題を再現します。

   ```bash
   # 例: シナリオ1の場合
   kubectl apply -f manifests/01-configmap.yaml
   ```

2. **問題を調査する**

   各シナリオの「🔍 問題の詳細を見る」セクションに記載されているコマンドを使って、問題の原因を特定します。

   - `kubectl get pods` でPodの状態を確認
   - `kubectl describe pod` で詳細情報を確認
   - `kubectl logs` でログを確認
   - `kubectl get events` でイベントを確認

3. **問題を解決する**

   原因を特定できたら、マニフェストファイルを編集して問題を修正します。
   ヒントが必要な場合は「✅ 解決方法を見る」を確認してください。

   ```bash
   # マニフェストファイルを編集
   vim manifests/01-configmap.yaml

   # 修正したマニフェストを再適用
   kubectl apply -f manifests/01-configmap.yaml
   ```

   > [!TIP]
   > `kubectl apply`は差分を検出して必要な変更のみを適用します。

4. **動作を確認する**

   ```bash
   # Podが正常に起動していることを確認
   kubectl get pods -n <namespace>

   # 必要に応じてログも確認
   kubectl logs <pod-name> -n <namespace>
   ```

5. **クリーンアップ**

   ```bash
   # マニフェストごと削除
   kubectl delete -f manifests/01-configmap.yaml
   ```

## Tips

### よく使うデバッグコマンド

```bash
# Podの状態を確認
kubectl get pods -A

# Podの詳細情報を確認
kubectl describe pod <pod-name> -n <namespace>

# Podのログを確認
kubectl logs <pod-name> -n <namespace>

# 前回のコンテナのログを確認（再起動した場合）
kubectl logs <pod-name> -n <namespace> --previous

# イベントを時系列で確認
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# リソースの使用状況を確認
kubectl top pods -n <namespace>
kubectl top nodes

# Podの詳細なYAMLを確認
kubectl get pod <pod-name> -n <namespace> -o yaml

# Podの中に入って調査
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
```

### トラブルシューティングのコツ

1. **エラーメッセージをよく読む**
   - `kubectl describe`の`Events`セクションに重要な情報が含まれています
   - エラーメッセージは問題の原因を直接示していることが多いです

2. **段階的に調査する**
   - まずPodの状態を確認（`kubectl get pods`）
   - 次に詳細情報を確認（`kubectl describe pod`）
   - 必要に応じてログを確認（`kubectl logs`）

3. **関連リソースも確認する**
   - PodだけでなくConfigMap、Secret、Serviceなども確認
   - `kubectl get all`で関連リソースを一覧表示

4. **公式ドキュメントを活用する**
   - Kubernetesの公式ドキュメントには詳細な情報が記載されています
   - エラーメッセージでGoogle検索すると解決策が見つかることも多いです

---

## まとめ

このチャプターでは、Kubernetesで頻繁に遭遇する5つのトラブルシューティングシナリオを体験しました。

- **ConfigMapの参照エラー**: キー名やリソース名の不一致
- **OOM Kill**: メモリのlimits設定不足
- **ImagePullBackOff**: イメージタグの問題（Bitnami等）
- **スケジューリング失敗**: TaintとTolerationの不一致
- **Ingress接続失敗**: クロスNamespace参照の制約

実際の運用では、これらの問題が複合的に発生することもあります。
今回学んだデバッグ手法とコマンドを活用して、効率的にトラブルシューティングを行えるようになりましょう。

> [!TIP]
> トラブルシューティングのスキルは、実際に問題に遭遇して解決することで磨かれます。
> エラーを恐れず、積極的に様々な設定を試してみてください！
