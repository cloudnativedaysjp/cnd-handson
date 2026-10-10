# Kubernetes概論ハンズオン

## 1. データの永続化 (PVとPVC)

ここまでのハンズオンで、コンテナの特性がある程度見えてきたかと思います。
おさらいすると、以下のような特性があります。

- カーネルを持たず、プロセスのような振る舞いをする
- 起動・停止がVMに比べて高速で行える
- データを自身で持たずエフェメラルな存在として扱う。

上記の特性から、コンテナのデータをどう扱う(システムとしてどう設計する)かは非常に重要な観点です。
このセクションでは、Nodeが持つストレージにPodをマウントさせ、データの永続化が確認できるまでのテストを行います。


PV(Persistent Volume)は外部ストレージとの接続を司るリソースです。
以下がPVを作成するためのサンプルコードです。


```Yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: handson-pv 
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /tmp
```


PVC(Persistent Volume Claim)は、PodのVolumeに関する要求事項を定義するためのリソースです。

```Yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: handson-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: standard
  resources:
    requests:
      storage: 1Gi
```


データの永続化を行うPodは、volumes属性に使いたいPVCの名前を書くことで作成できます。

```Yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume-pod
spec:
  containers:
  - name: volume-app
    image: busybox
    command: ["/bin/sh"]
    args: ["-c","while true; do echo $(date -u) >> /data/out1.txt; sleep 5; done"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: handson-pvc
```


以下のコマンドで各リソースの作成を行います。


```sh
kubectl apply -f handson-volume.yaml
```


以下のコマンドで各リソースの確認を行います。

```sh
kubectl get pv,pvc,pods
kubectl describe pv handson-pv
kubectl describe pvc handson-pvc
```

今回のシナリオでは、5秒ごとにdateコマンドで日付をマウント先のファイル`/data/out1.txt`に書き込むPodを作成しています。
以下のコマンドで動作確認が行えます。

```sh
kubectl exec volume-pod -- tail /data/out1.txt
```

動作確認後、リソースの削除を行います。


```sh
kubectl delete pod volume-pod
kubectl delete pvc handson-pvc
kubectl delete pv handson-pv
```

### 2. Init Container


PodはKubernetesにおける最小の単位ですが、その実態は複数(単独の場合もある)のコンテナで実行するリソースです。
例えば、Service Meshを実現するためにネットワークプロキシとなるコンテナAとサービスアプリケーションとなるコンテナBを1つのPodとして稼働させることで、ネットワーク周りの処理をコンテナBに任せてコンテナはサービスの提供に全てのリソースを割くといったことができます。
また、init containerと呼ばれる一時的な用途のコンテナを作成することも可能です。

今回はinit containerの動作を確認してみましょう。
このシナリオでは、起動時に作成されるコンテナ(Init Container)が`Welcome to the CND Handson!!`というメッセージを出力するコンテンツを作成しマウント先のボリュームに保存します。
その後、nginxが起動しInit Containerが作成したコンテンツを参照することで、nginxにアクセスした際に上記メッセージが返却されます。

まずは以下のManifestをapplyします。

```sh
kubectl apply -f handson-init.yaml
```

続いて、動作確認のためPodのIPを確認します。

```sh
kubectl get pods -o wide | grep init
```

最後に一時的な確認Podを使ってcurlでのアクセス確認をしてみましょう。


```sh
kubectl run tmp --restart=Never --rm -i --image=nginx:alpine -- curl <PodのIP>
```

以下のように`Welcome to the CND Handson!!`のメッセージが確認できます。


```
# 実行結果


  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    11  100    11    0     0   4776      0 --:--:-- --:--:-- --:--:--  5500
CNDW2025!!
pod "tmp" deleted from default namespace
```

動作確認後、リソースを削除します。

```sh
kubectl delete deployment handson-init-container
```


### 3. 認証・認可

すべてのKubernetesクラスターには、2種類のユーザーがあります。Kubernetesによって管理されるService Accountと、通常のユーザーです。

Service AccountはKubernetes APIによって管理されるユーザーです。特定の名前空間にバインドされており、APIサーバーによって自動的に作成されるか、APIコールによって手動で作成されます。
また、Service Accountは、Secretsとして保存された資格情報の集合に紐付けられています。これをPodにマウントすることで、クラスター内のプロセスがKubernetes APIと通信できるようにします。

一方、クラスターから独立したサービスは通常のユーザーを以下の方法で管理することを想定されています。

- 秘密鍵を配布する管理者
- KeystoneやGoogle Accountsのようなユーザーストア
- ユーザー名とパスワードのリストを持つファイル
  
これを考慮すると、 Kubernetesは通常のユーザーアカウントを表すオブジェクトを持ちません。 APIコールを介して、通常のユーザーをクラスターに追加することはできません。

APIコールを介して通常のユーザーを追加できませんが、クラスターの認証局(CA)に署名された有効な証明書で表すユーザーは認証済みと判断されます。
この構成では、Kubernetesは証明書の‘subject’内にある一般的な名前フィールド(例えば、“/CN=bob”)からユーザー名を特定します。
そこから、ロールベースアクセス制御(RBAC)サブシステムは、ユーザーがあるリソースにおける特定の操作を実行するために認証済みかどうか特定します。


#### 3.1. Service Accountの作成と動作確認

> ServiceAccount作成

```sh
kubectl get serviceaccounts
kubectl create serviceaccount handson-sa
kubectl get serviceaccounts
```

> Role作成

```sh
kubectl get role
kubectl create role handson-role --resource=pods --verb=get,watch,list
kubectl get role
```

> RoleBinding作成

```sh
kubectl get rolebinding
kubectl create rolebinding handson-rolebinding --role=handson-role --serviceaccount=default:handson-sa
kubectl get rolebinding
```

> Podデプロイ

```sh
kubectl apply -f kubectl-pod.yaml
```

> ログからコマンドを実行していることを確認

```sh
kubectl logs kubectl-pod
```

> 一度Podを削除し、コマンドを変更して再デプロイ

```sh
kubectl delete pod kubectl-pod
```

vimなどのエディタを使って、Pod内で実行するコマンドを変更します。

```Yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubectl-pod
spec:
  containers:
  - image: bitnami/kubectl
    name: kubectl
    command:
    - sh
    - -c
    - |
      while true
      do
        kubectl get deployment # 変更箇所
        sleep 30
      done
  serviceAccountName: handson-sa
```

```sh
kubectl apply -f kubectl-pod.yaml
```

> ログからコマンドが弾かれていることを確認

```sh
kubectl logs kubectl-pod
```

>確認できたらPodを削除

```sh
kubectl delete pod kubectl-pod
```

#### 3.2. ユーザの作成と動作確認

続いてユーザの作成を行います。
前述した通り、KubernetesにはユーザーをAPIコールによって追加することはできませんが、Kuberrnetes Cluster内の認証局にて署名された証明書を持たせることによって、認証されたユーザーとしてAPIを呼び出すことができるようになります。
今回は、CSRの作成後、認証局での承認を行い証明書を発行したのち、roleの作成を行い実際の動作確認を行います。
その後、新しいクレデンシャルを作成し、contextを切り替えることで追加したユーザを使ったAPIコールの動作確認を行います。
尚、本シナリオはPodに関する操作のみが行えるroleを作成します。

> 秘密鍵とCSRの作成

まずは秘密鍵とCSRの作成を行います。

```sh
openssl genrsa -out handson-user.pem 2048
openssl req -new -key handson-user.pem -out handson-user.csr -subj "/CN=handson-user"
```

> CSRをbase64にエンコード

```sh
cat handson-user.csr | base64 | tr -d '\n'
```

> CSRの作成

handson-csr.yamlを用意しています。
その中に、先ほどエンコードした文字列を貼り付けます。


```Yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: handson-user
spec:
  signerName: kubernetes.io/kube-apiserver-client
  request: <base64でエンコードしたテキストを貼り付ける>
  usages:
  - client auth
```

その後、Manifestをapplyします。

```sh
kubectl apply -f handson-csr.yaml
```

> CSRをApprove

続いて、作成したCSRをApploveします。

```sh
kubectl get csr
```

```sh
kubectl certificate approve handson-user
```

```sh
kubectl get csr
```

> 証明書の取得

続いて、CSRから証明書を取得します。
実際の証明書の値は`status.certificate`を見ると確認できます。

```sh
kubectl get csr/handson-user -o yaml
```

これをbase64でencodeした形でエクスポートします。


```sh
kubectl get csr handson-user -o jsonpath='{.status.certificate}'| base64 -d > handson-user.crt
```

> Role作成

`handson-user`に割り当てるroleを作成します。
今回はPodに関する一連の操作のみを許可する設定です。

```sh
kubectl get role
kubectl create role handson-user-role --resource=pods --verb=create,list,get,update,delete,watch
kubectl get role
```

> RoleBinding作成

続いてRoleBindingを作成します。先ほど作成したRoleとhandson-userを実際に紐づける設定です。

```sh
kubectl get rolebinding
kubectl create rolebinding handson-user-rolebinding --role=handson-user-role --user=handson-user
kubectl get rolebinding
```

> kubeconfigに追加

以下のコマンドで、新しいクレデンシャルを追加します。

```sh
kubectl config set-credentials handson-user --client-key=handson-user.pem --client-certificate=handson-user.crt --embed-certs=true
```

続いて、contextを追加します。


```sh
kubectl config set-context handson-user --cluster=kind-kind --user=handson-user
```

追加されると、以下のようにcontextが増えているのが確認できます。

```sh
kubectl config get-contexts
```


```Log
CURRENT   NAME           CLUSTER     AUTHINFO       NAMESPACE
          handson-user   kind-kind   handson-user   
*         kind-kind      kind-kind   kind-kind
```

続いて、handson-userにcontextを変更します。

```sh
kubectl config use-context handson-user
```

再度contextの状態を確認すると、handson-userに*が付いていることがわかります。

```Log
CURRENT   NAME           CLUSTER     AUTHINFO       NAMESPACE
*         handson-user   kind-kind   handson-user   
          kind-kind      kind-kind   kind-kind
```



```sh
kubectl config get-contexts
```

> 動作確認

この状態でいくつかコマンドを実行してみます。


まずはPodの作成、確認コマンドを実行します。
Podの作成、確認に関してはroleにより権限が付与されているため実行可能です。

```sh
kubectl run test --image=nginx
```

```sh
kubectl get pods
```

```Log
NAME   READY   STATUS    RESTARTS   AGE
test   1/1     Running   0          28s
```

削除も同様に行うことが可能です。

```sh
kubectl delete pod test
```

しかしながら、Deploymentなど他のリソースに関するロールは割り当てられていないためエラーとなります。

```sh
kubectl create deployment test --image=nginx
```

```Log
error: failed to create deployment: deployments.apps is forbidden: User "handson-user" cannot create resource "deployments" in API group "apps" in the namespace "default"
```

続いて、contextを元々使用していたものに再度変更し同じコマンドを実行してみます。

```sh
kubectl config use-context kind-kind
```

```sh
kubectl create deployment test --image=nginx
```

問題なく実行できることが確認できます。

```sh
kubectl get deployment
```

```Log
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
test   1/1     1            1           8s
```

動作確認後、リソースを削除します。

```sh
kubectl config delete-context handson-user 
kubectl delete rolebinding handson-user-rolebinding 
kubectl delete role handson-user-role
kubectl delete csr handson-user
kubectl delete deployment test
```



## 4. Readiness/Liveness Probe

KubernetesにはPodが正常に起動したか、または正常に動作を続けているかを監視する機能が存在します。
このセクションで取り扱うReadiness/Liveness Probeは、コマンドの実行結果やTCP・HTTPリクエストなどのリターンコードによって
そのPodの準備が出来ているかどうか、または正常に動作しているかどうかを判断します。


以下はヘルスチェックのオプションです。


- initialDelaySeconds

  
  初回ヘルスチェックまでの遅延時間（秒）

  
- periodSeconds

  
  Probeが実行される間隔（秒）

  
- timeoutSeconds

  
  タイムアウトまでの時間（秒）

  
- successThreshold

  
  成功と判断する最小連続成功数（回数）

  
- failureThreshold

  
  失敗と判断する試行回数（回数）


### 4.1 Readiness Probe

今回は`/tmp/ready`ファイルの有無によって、Podの準備が出来ているかを判断するシナリオです。
まずは対象のファイルを作成しない状態でPodをデプロイしてみます。


```sh
kubectl apply -f readiness-pod.yaml
```

対象のファイルが作成されていない状態ではPodがReadyのステータスにならないことがわかります。

```sh
kubectl get pods
```

```Log
# 実行結果

NAME                    READY   STATUS    RESTARTS      AGE
readiness-pod           0/1     Running   0             7s
```


続いてreadiness-pod.yamlを以下のように編集して、コンテナ内に対象のファイルを作成するようにします。

```Yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: readiness-pod
  name: readiness-pod
spec:
  containers:
  - command:
    - sh
    - -c
    - touch /tmp/ready && sleep 1d # 編集
    image: busybox:1.31.0
    name: readiness-container
    resources: {}
    readinessProbe:
      exec:
        command:
        - sh
        - -c
        - cat /tmp/ready
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 1
      successThreshold: 1
      failureThreshold: 1
```

以下のコマンドでPodを入れ替えてみましょう。

```sh
kubectl replace -f readiness-pod.yaml --force
```

再度Podの状態を確認すると、状態がReadyになっていることが確認できます。


```Log
# 実行結果


NAME                    READY   STATUS    RESTARTS      AGE
readiness-pod           1/1     Running   0             7s
```

動作確認後、リソースを削除します。

```sh
kubectl delete pod readiness-pod
```

### 4.2 Liveness Probe


続いて、Liveness Probeの動作確認を行います。
Readiness Probe同様、ファイルの有無によってPodの正常性を確認します。
このシナリオでは`/tmp/healthy`ファイルが自動的に削除されます。
そのため、ヘルスチェックに失敗したPodは自動的にリスタートを行います。

まず、PodをApplyします。

```sh
kubectl apply -f liveness-pod.yaml
```

以下のコマンドでPodの挙動が確認できます。
Pod作成からしばらく経つと、`RESTARTS`のカウンタが上昇していくのが確認できます。

```sh
watch -n 1 kubectl get pods
```

動作確認後、リソースを削除します。

```sh
kubectl delete pod liveness-pod
```

## 5. Network Policy

Network PolicyはPod同士の通信を制御し、特定のPodやプロトコルを許可/拒否させることができるリソースです。

前提として、以下のCNIのいずれかを使ってクラスタを構築している必要があります。

- Calico
- Cilium
- Kube-router
- Romana
- Weave Net

尚、今回はCiliumを使用しています。

設定方法として、以下を意識する必要があります。

- 通信の方向
  - Ingress：　あるPodからの通信（インバウンド）
  - Egress：　あるPodへの通信（アウトバウンド）
- Policy
  - podSelector: あるPodから、もしくはあるPodへの通信可否
  - namespaceSelector: あるNamespaceから、もしくはあるNamespaceへの通信可否
  - ipBlock: あるIPアドレスから、もしくはあるIPアドレスへの通信可否

今回は3つのテスト用のPodをデプロイし、curlを使って通信確認を行なっていきます。

```sh
kubectl apply -f netpol-pod.yaml
```

通信確認を行うためにPodに付与されているIPアドレスを確認します。

```sh
kubectl get pods -o wide -L app | grep app
```

以下のように、curlを使ってPod同士の通信確認をそれぞれ行なっていきます。

```sh
kubectl exec -it nginx-app1 -- curl -I <PodのIP>
kubectl exec -it nginx-app2 -- curl -I <PodのIP>
kubectl exec -it nginx-app3 -- curl -I <PodのIP>
```

続いて、すべての通信を拒否するNetwork Policyを適用します。


```sh
kubectl apply -f default-deny-all.yaml
```

先ほどと同じようにcurlを投げても、タイムアウトになることが確認できます。

```sh
kubectl exec -it nginx-app1 -- curl -I <PodのIP>
kubectl exec -it nginx-app2 -- curl -I <PodのIP>
kubectl exec -it nginx-app3 -- curl -I <PodのIP>
```

続いて、`app1`と`app3`同士の通信のみが許可されるポリシーを適用していきます。
今回は`podSelector`を使用してポリシーを設定しています。

```sh
kubectl apply -f handson-policy.yaml
```

設定後、`app1`と`app3`同士の通信のみが可能であることが確認できます。

```sh
kubectl exec -it nginx-app1 -- curl -I <PodのIP>
kubectl exec -it nginx-app2 -- curl -I <PodのIP>
kubectl exec -it nginx-app3 -- curl -I <PodのIP>
```

動作確認後、リソースを削除します。

```sh
kubectl delete networkpolicy default-deny-all
kubectl delete networkpolicy app1-app3
kubectl delete networkpolicy app3-app1
kubectl delete pod nginx-app1
kubectl delete pod nginx-app2
kubectl delete pod nginx-app3
```



## 6. JobとCronJob

### 6.1. Job

Jobは、ReplicaSetと同様、Podを管理するためのPodの上位リソースに該当します。
Podを使って一時的な処理を行う際に利用するリソースで、処理を実行後にPodは自動的に削除されます。
今回はechoでメッセージを出力する簡単なJobを実行します。

Jobリソースは、並列動作や繰り返し動作に関するオプションのパラメータを設定することが可能です。


- completion
  指定した回数Podが正常終了したら、Jobが終了する
- parallelism
  指定した数値分Podを並列で起動する
- backoffLimit
  指定した回数分Podをリトライする。リトライ回数が上限に達するとエラー判定となる


今回は以下のように設定しているため、計6回Jobが実行され
2つのPodが並列で動作します。

```Yaml
completion: 6
parallelism: 2
```

以下のManifestを適用します。

```sh
kubectl apply -f handson-job.yaml
```

動作確認は以下のコマンドで行います。

```sh
kubectl get job
```

以下のように、完了したJobは`COMPLETIONS`としてカウントされていきます。

```Log
# 実行結果


NAME          COMPLETIONS   DURATION   AGE
handson-job   6/6           15s        58s
```

また、Podの挙動を観察することで動作確認をすることも可能です。
以下のコマンドで2つずつ並列でJobが実行されていくのが確認できます。

```sh
watch -n 1 kubectl get pod
```

実際のJobの実行結果はLogを確認します。

```sh
kubectl logs <Pod名>
```

確認が完了したらリソースを削除します。


```sh
kubectl delete job handson-job
```

### 6.2. CronJob

CronJobは、リソース内のCronに従って、スケジュールされた時間にJobを実行します。
CronJobは、先ほど実行したJobの上位リソースに当たります。

今回は1分ごとにJobを動作させるシナリオです。
それでは、前回のJobのシナリオ同様にManifestをapplyして動作を確認していきましょう。

```sh
kubectl apply -f handson-cronjob.yaml
```

1分ごとにJobが増えていくのが確認できます。

```sh
watch -n 1 kubectl get pods
```

今回はdateコマンドを実行するJobなので、日付が出力されているはずです。

```sh
kubectl logs <Pod名>
```

以下のコマンドはCron Jobのステータスや詳細が確認できます。

```sh
kubectl get cronjob
```

```sh
kubectl describe cronjob handson-cronjob
```

Cron Jobを一時停止したい場合は、kubectl patchコマンドを使用します。
リソース内の`spec.suspend`パラメータを`true`にすることで停止が可能です。

`kubectl get cronjob`を実行すると、現在は`SUSPEND`が`False`になっていることが確認できます。

```Log
# 実行結果


NAME              SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
handson-cronjob   */1 * * * *   False     0        24s             7m24s
```

以下のコマンドを実行します。

```sh
kubectl patch cronjob handson-cronjob -p '{"spec":{"suspend":true}}'
```

実行後、以下のようにステータスが変更されていることが確認できます。

```Log
# 実行結果


NAME              SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
handson-cronjob   */1 * * * *   True      0        8s              13m
```

動作確認後、リソースを削除します。


```sh
kubectl delete cronjob handson-cronjob
```

## 7. ConfigMap

ConfigMapは、機密性のないデータをキーと値のペアで保存するために使用されるリソースです。
環境固有の設定などをコンテナイメージから分離できるため、アプリケーションを簡単に移植できるようになります。

但し、機密性や暗号化の機能を持たないため保存したいデータが機密情報である場合はSecretやサードパーティツールを使用する必要があります。
今回は`CND ConfigMap Handson`というHTML形式のデータをConfigMapに保存し、Podにマウントさせています。
クライアントからのリクエストはマウントされたConfigMapのHTMLデータを参照するため、`CND ConfigMap Handson`という文字列が返却されるはずです。



まずは、ConfigMapを作成します。

```sh
kubectl apply -f handson-configmap.yaml
```

続いてPodを作成します。

```sh
kubectl apply -f configmap-pod.yaml
```

次に、PodにアクセスするためIPアドレスを調べます。以下のコマンドでPodに紐づくIPアドレスが判ります。

```sh
kubectl get pods -o wide
```

最後にテンポラリのPodを作成し、curlでアクセスを試みます。
`CND ConfigMap Handson`という文字列が返却されると成功です。

```sh
kubectl run tmp --restart=Never --rm -i --image=nginx:alpine -- curl <PodのIPアドレス>
```

動作確認後、リソースを削除します。

```sh
kubectl delete pod configmap-pod
kubectl delete configmap handson-configmap
```

## 8. Resources

KubernetesにはNamespace単位でリソースを制御することができるResource Quotaという機能があります。
制御できる機能は以下です。

- Compute Resource Quota
- Storage Resource Quota
- Object Count Quota

今回はCompute Resource Quotaを使ってCPU/メモリに対して上限と下限を設定するシナリオを用意しています。

まずは`resource-test`という名前のnamespaceを作成します。


```sh
kubectl create namespace resource-test
```

以下のようにnamespaceが作成されます。

```sh
kubectl get namespace
```

```Log
# 実行結果

NAME                 STATUS   AGE
resource-test        Active   6s
```

続いて、作成したnamespaceにCompute Resource Quotaを設定します。

```sh
kubectl apply -f test-resource-quota.yaml 
```

以下のように作成されていることが確認できます。


```sh
kubectl get resourcequotas -n resource-test
```

> 出力例

```Log
# 実行結果


NAME                  AGE   REQUEST   LIMIT
test-resource-quota   14s             limits.cpu: 0/200m, limits.memory: 0/200Mi
```

続いて、テスト用Podのデプロイを試みます。
今回はテスト用のDeployment Manifestを用意しています。

```sh
kubectl apply -f resource-test.yaml
```


動作確認をすると、Podが起動していないことが確認できます。

```sh
kubectl get pods -n resource-test
```



```
# 実行結果

No resources found in resource-test namespace.
```

Deploymentも同様にREADYのPodが0であることが確認できます。

```sh
kubectl get deployments -n resource-test
```



```Log

# 実行結果

NAME            READY   UP-TO-DATE   AVAILABLE   AGE
resource-test   0/1     0            0           52s
```

この時、Replicasetの状態を確認するとCPUやMemoryなどQuotaで設定したリソースの制限は必須であるため、エラーになっていることが判ります。

```sh
kubectl describe -n resource-test replicasets.apps resource-test
```


```Log
# 実行結果


Name:           resource-test-6cb9b54b4c
Namespace:      resource-test
Selector:       app=resource-test,pod-template-hash=6cb9b54b4c
Labels:         app=resource-test
                pod-template-hash=6cb9b54b4c
Annotations:    deployment.kubernetes.io/desired-replicas: 1
                deployment.kubernetes.io/max-replicas: 2
                deployment.kubernetes.io/revision: 1
Controlled By:  Deployment/resource-test
Replicas:       0 current / 1 desired
Pods Status:    0 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=resource-test
           pod-template-hash=6cb9b54b4c
  Containers:
   nginx:
    Image:        nginx:latest
    Port:         <none>
    Host Port:    <none>
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Conditions:
  Type             Status  Reason
  ----             ------  ------
  ReplicaFailure   True    FailedCreate
Events:
  Type     Reason        Age                  From                   Message
  ----     ------        ----                 ----                   -------
  Warning  FailedCreate  10m                  replicaset-controller  Error creating: pods "resource-test-6cb9b54b4c-s9m9f" is forbidden: failed quota: test-resource-quota: must specify limits.cpu for: nginx; limits.memory for: nginx
  Warning  FailedCreate  10m                  replicaset-controller  Error creating: pods "resource-test-6cb9b54b4c-xchht" is forbidden: failed quota: test-resource-quota: must specify limits.cpu for: nginx; limits.memory for: nginx
  Warning  FailedCreate  10m                  replicaset-controller  Error creating: pods "resource-test-6cb9b54b4c-hs6tz" is forbidden: failed quota: test-resource-quota: must specify limits.cpu for: nginx; limits.memory for: nginx
  Warning  FailedCreate  10m                  replicaset-controller  Error creating: pods "resource-test-6cb9b54b4c-qdph7" is forbidden: failed quota: test-resource-quota: must specify limits.cpu for: nginx; limits.memory for: nginx
  Warning  FailedCreate  10m                  replicaset-controller  Error creating: pods "resource-test-6cb9b54b4c-dxflr" is forbidden: failed quota: test-resource-quota: must specify limits.cpu for: nginx; limits.memory for: nginx
  Warning  FailedCreate  10m                  replicaset-controller  Error creating: pods "resource-test-6cb9b54b4c-xfw8z" is forbidden: failed quota: test-resource-quota: must specify limits.cpu for: nginx; limits.memory for: nginx
  Warning  FailedCreate  10m                  replicaset-controller  Error creating: pods "resource-test-6cb9b54b4c-465t2" is forbidden: failed quota: test-resource-quota: must specify limits.cpu for: nginx; limits.memory for: nginx
  Warning  FailedCreate  10m                  replicaset-controller  Error creating: pods "resource-test-6cb9b54b4c-6ml62" is forbidden: failed quota: test-resource-quota: must specify limits.cpu for: nginx; limits.memory for: nginx
  Warning  FailedCreate  10m                  replicaset-controller  Error creating: pods "resource-test-6cb9b54b4c-bvc5t" is forbidden: failed quota: test-resource-quota: must specify limits.cpu for: nginx; limits.memory for: nginx
  Warning  FailedCreate  5m15s (x8 over 10m)  replicaset-controller  (combined from similar events): Error creating: pods "resource-test-6cb9b54b4c-z92sl" is forbidden: failed quota: test-resource-quota: must specify limits.cpu for: nginx; limits.memory for: nginx
```

では、先ほどのDeployment Manifest resource-test.yamlをvimなどのエディタを利用して編集し、リソースの上限と下限を割り当ててみましょう。

```Yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-test
  namespace: resource-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-test
  template:
    metadata:
      labels:
        app: resource-test
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ## ↓ここから追記
          resources:
            requests:
              memory: 100Mi
              cpu: 100m
            limits:
              memory: 200Mi 
              cpu: 200m 
```


再度Deployment Manifestをapplyします。

```sh
kubectl apply -f resource-test.yaml 
```

すると、Podが対象のnamespaceにデプロイされたことが確認できます。

```sh
kubectl get pods -n resource-test 
```



```Log
# 実行結果


NAME                             READY   STATUS    RESTARTS   AGE
resource-test-695d9849c7-6dg2v   1/1     Running   0          8s
```

動作確認後、リソースを削除します。

```sh
kubectl delete -n resource-test deployments.apps resource-test
kubectl delete -n resource-test resourcequotas test-resource-quota
kubectl delete namespaces resource-test
```

### 9. トラブルシュート

セクションの最後に、簡単なWebアプリケーションを使ったトラブルシュートに挑戦してみましょう。
構成図右下にあるcnd-web-appに接続し、適切なWebページを表示させることがゴールです。

![diagram](./image/cnd-tshoot-diagram.svg)

> [!NOTE]
> - 動作確認は、ブラウザから以下のURLにアクセスすることで行います。
>   - http://cnd-web.example.com
> - リソースの更新後もWeb画面の表示が変わらない場合があります。1-2分待ってからブラウザのリフレッシュを行なってください。
> - 改修箇所は1箇所ではない可能性があります。また、構成図とエラーメッセージがヒントになる場合があります。


以下のコマンドでアプリのデプロイを行なってください。
```sh
kubectl apply -f cnd-web.yaml
```


動作確認後、リソースを削除します。

```sh
kubectl delete pod cnd-web-app
kubectl delete pod dummy-app
kubectl delete pod mysql
kubectl delete service cnd-web-svc
kubectl delete service mysql-svc
kubectl delete ingress cnd-web-ing
kubectl delete secret app-secret
```


### 10. おまけ(jsonpath)

jsonpathは、ワンライナーで欲しい情報のみを引き抜く際に便利な機能です。
jsonpathでNodeの内部IPのみをファイルに書き出してみましょう。

```sh
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' > <ファイルのPathとファイル名>
```
