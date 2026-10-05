# トラブルシューティング - 解決方法

このファイルには、各トラブルシューティングシナリオの解決方法が記載されています。

---

## 環境変数が読み込めずPodが起動しない

<details>
<summary>解説を見る</summary>

### 原因
ConfigMapを環境変数として参照する際、以下のいずれかの問題が発生しています:
1. ConfigMapのキー名が実際のキー名と一致していない
2. ConfigMapの名前が間違っている
3. ConfigMapが存在しないnamespaceを参照している

### 解決策
ConfigMapのキー名とConfigMap名を正しく修正します。

**修正内容**:
```yaml
env:
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: config
      key: database_host  # db_host → database_host に修正

- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: config  # app-config → config に修正
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

kubectl describe pod $(kubectl get pods -n troubleshoot -l app=app-configmap -o jsonpath='{.items[0].metadata.name}') -n troubleshoot

# マニフェストを修正して再適用
# 修正内容: ConfigMap名とキー名を正しく修正
kubectl apply -f manifests/01-configmap.yaml

# Podが正常に起動していることを確認
kubectl get pods -n troubleshoot

# 環境変数が正しく設定されているか確認
kubectl logs $(kubectl get pods -n troubleshoot -l app=app-configmap -o jsonpath='{.items[0].metadata.name}') -n troubleshoot | grep -E "DB_HOST|LOG_LEVEL"
```
</details>

---

## Podが何度も再起動を繰り返す

<details>
<summary>解説を見る</summary>

### 原因
アプリケーションが必要とするメモリよりも、resourcesのlimitsで設定されたメモリが少ないため、OOM (Out Of Memory) Killerによってコンテナが強制終了されます。

### 解決策
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
kubectl get pods -n troubleshoot
kubectl describe pod $(kubectl get pods -n troubleshoot -l app=app-oom -o jsonpath='{.items[0].metadata.name}') -n troubleshoot

# マニフェストを修正して再適用
# 修正内容: memory limits: 128Mi → 512Mi, requests: 64Mi → 256Mi
kubectl apply -f manifests/02-oom.yaml

# Podが正常に起動していることを確認
kubectl get pods -n troubleshoot

# メモリ使用量を確認
kubectl top pod -n troubleshoot
```
</details>

---

## コンテナイメージが取得できない

<details>
<summary>解説を見る</summary>

### 原因
Bitnamiは2024年頃からイメージのタグ付けポリシーを変更し、特定バージョンのタグを削除する方針になりました。最新版のみを`latest`タグで提供するため、以前使えていた特定バージョン（例：`bitnami/nginx:1.25.0`）のタグが突然削除され、イメージがPullできなくなります。

**参考**: [Bitnamiコンテナイメージがpullできない問題 - Qiita](https://qiita.com/m-masataka/items/73383c77cf2e2b8592f0)

### 解決策

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
</details>

---

## PodがPendingのまま起動しない

<details>
<summary>解説を見る</summary>

### 原因
NodeにはTaintが設定されており、PodにはそれをTolerate（許容）するTolerationが必要です。しかし、Tolerationの`effect`が間違っているため、PodがNodeにスケジュールされません。

**Taintとは**:
- Nodeに「特定の条件を満たすPodのみをスケジュールする」という制約を設定する機能
- 例: `workload=batch:NoSchedule` は「workload=batchをTolerateするPodのみをスケジュールする」という意味

**Tolerationとは**:
- PodがNodeのTaintを許容するための設定
- key、value、effectがNodeのTaintと完全に一致する必要がある

### 解決策
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
kubectl get pods -n troubleshoot
kubectl describe pod $(kubectl get pods -n troubleshoot -l app=app-scheduling -o jsonpath='{.items[0].metadata.name}') -n troubleshoot

# マニフェストを修正して再適用
# 修正内容: effect: "NoExecute" → "NoSchedule"
kubectl apply -f manifests/04-scheduling.yaml

# Podが正常にスケジュールされることを確認
kubectl get pods -n troubleshoot

# どのNodeにスケジュールされたか確認
kubectl get pods -n troubleshoot -o wide
```

**後片付け**:
```bash
# taintを削除
kubectl taint nodes <node-name> workload=batch:NoSchedule-
```
</details>

---

## HTTPRouteでエラーが発生する

<details>
<summary>解説を見る</summary>

### 原因
Gateway APIでは、HTTPRouteが別のnamespaceのServiceを`backendRefs`に指定することができますが、
参照される側のnamespaceに`ReferenceGrant`が存在しない限り、その参照は許可されません。
これは、あるnamespaceの管理者が知らないうちに別namespaceからServiceを参照されることを防ぐための仕組みです。

今回の構成では:
- `troubleshoot` namespaceにHTTPRouteがある
- HTTPRouteから`frontend`/`backend` namespaceのServiceを参照しようとしている
- しかし、`frontend`/`backend` namespaceに`ReferenceGrant`が存在しない
- そのため、HTTPRouteの`status`に`ResolvedRefs: False`（`reason: RefNotPermitted`）が記録され、
  該当ルートへのアクセスは500エラーになる

### 解決策
参照される側のnamespaceに`ReferenceGrant`を作成し、`troubleshoot` namespaceのHTTPRouteから
Serviceを参照することを明示的に許可します。

**手順**:
1. `frontend`と`backend` namespaceに、`troubleshoot` namespaceのHTTPRouteからのService参照を許可する`ReferenceGrant`を作成
2. HTTPRouteの`backendRefs`はそのまま、別namespaceのServiceを直接参照する

**修正内容**:
```yaml
# 参照される側のnamespaceにReferenceGrantを作成
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-troubleshoot-httproute
  namespace: frontend
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: troubleshoot
  to:
  - group: ""
    kind: Service
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-troubleshoot-httproute
  namespace: backend
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: troubleshoot
  to:
  - group: ""
    kind: Service
```

**確認方法**:
```bash
# マニフェストを適用
kubectl apply -f manifests/05-httproute.yaml

# HTTPRouteの状態を確認（RefNotPermittedが発生するはず）
kubectl get httproute -n troubleshoot
kubectl describe httproute httproute -n troubleshoot

# ReferenceGrantが存在しないことを確認
kubectl get referencegrant -A

# 各namespaceのServiceを確認
kubectl get svc -n troubleshoot
kubectl get svc -n frontend
kubectl get svc -n backend

# マニフェストを修正して再適用
# 修正内容: frontend/backendネームスペースにReferenceGrantを追加
# 詳細は上記の「修正内容」セクションを参照
kubectl apply -f manifests/05-httproute.yaml

# HTTPRouteが正しく動作しているか確認（ResolvedRefsがTrueになる）
kubectl get httproute httproute -n troubleshoot -o jsonpath='{.status.parents[0].conditions}' | jq

# curlで疎通確認
curl http://troubleshoot.example.com/
curl http://troubleshoot.example.com/api

# クリーンアップとして、作成したReferenceGrantを削除
kubectl delete referencegrant allow-troubleshoot-httproute -n frontend
kubectl delete referencegrant allow-troubleshoot-httproute -n backend
```
</details>
