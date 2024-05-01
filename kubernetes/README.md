# Kubernetesハンズオン

## 1. 事前準備

まずは、CLIツールが正常に動作しているか確認します。
以下のコマンドを入力してください。

```Bash
kubectl get nodes
```

Nodeの一覧が出力されるはずです。

```Log
NAME                 STATUS   ROLES           AGE   VERSION
kind-control-plane   Ready    control-plane   30d   v1.27.3
kind-worker          Ready    <none>          30d   v1.27.3
kind-worker2         Ready    <none>          30d   v1.27.3
```

Nodeが表示されない場合は、kubeconfigが設定されていない可能性があります。

以下のコマンドでkubeconfigの設定を確認します。

```Bash
kubectl config get-contexts
```

```
CURRENT   NAME        CLUSTER     AUTHINFO    NAMESPACE
*         kind-kind   kind-kind   kind-kind   
```


Kubernetesは、kubectlというCLIツールを提供しています。
kubectlは、ネットワークリーチャビリティのあるController NodeにAPIのリクエストを送ることで
リモートでの操作を可能にするものです。
正しくセットアップされていないとAPIリクエストを送ることができずに
Kubernetesの操作ができなくなってしまいます。

以下のコマンドでkubectlコマンドのバージョンの確認ができます。
```Bash
kubectl version --client
```

```
Client Version: v1.28.1-eks-43840fb
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
```

続いて、kubectlのコマンド補完の設定を行います。

> 現在のbashシェルにコマンド補完を設定するには、最初にbash-completionパッケージをインストールする必要があります。

```Bash
source <(kubectl completion bash)
```

> bashシェルでのコマンド補完を永続化するために.bashrcに追記します。

```Bash
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

> 下記までの設定を行うと、コマンド補完が行え"k"のみでkubectlとみなされます。

```
alias k=kubectl
complete -F __start_kubectl k
```

## 2. アプリケーションデプロイ

### 2.1. NameSpaceの作成

まずは自身のNameSpaeを作成していきます。
以下のコマンドを入力してください。

```Bash
kubectl create namespace <namespace名>
```

以下のコマンドでNameSpaceの一覧が確認できます。

```Bash
kubectl get namespace
```

### 2.2 Deployment manifestファイル作成

続いて、manifestファイルを作成します。
manifestファイルはyaml形式もしくはjson形式がサポートされています。
今回はyaml形式のmanifestを用意しています。


### 2.3. Deploymentの適用

続いて、作成したManifestを使ってPodをNode上に構築します。
以下のコマンドを入力してください。

```Bash
cd manifest
kubectl apply -f test-deployment.yaml -n <namespace名>
```

以下のコマンドでPodの確認ができます。

```Bash
kubectl get pods -n <namespace名>
```

### 2.4. ポートフォワードと通信確認

続いて、作成したPodにアクセスします。
今回はポートフォワードを使いインターネット上のpodにアクセスしていきます。

```Bash
kubectl port-forward <Pod名>  8888:80 -n <namespace名>
```

以下のように出力されたら操作が受け付けられなくなりますが、ctrl＋Cを押さずにそのままでいてください。

```Log
Forwarding from 127.0.0.1:8888 -> 80
Forwarding from [::1]:8888 -> 80
```

この時点でアクセスが可能になっているはずなので、新しくターミナルを開き、以下のコマンドでアクセスしてみましょう。

```Bash
curl http://localhost:8888
```


成功すると、nginxのテストページが表示されるはずです。

### 2.5 Pod削除

続いて、Podを削除してみます。
以下のコマンドを入力してください。

```Bash
kubectl delete pod <pod名> -n <namespace名>
```

Pod名、及び削除されたかどうかは以下で調べることができます。

```Bash
kubectl get pod -n <namespace名>
```

上記の対応では、対象PodのRESTARTSのみがリセットされPodが削除できていないことがわかります。
Kubernetesはあるべき状態をPodの上位概念のManifestが定義しています。
このケースではPodを削除したことをトリガーにあるべき状態、つまり対象のPodが1つ存在する状態に戻そうとDeploymentが働きかけたことが原因です。
このようなケースでPodを完全に削除したい場合はDeploymentごと削除する必要があります。

まず、以下のコマンドでDeploymentの状態を確認します。

```Bash
kubectl get deployments -n <namespace名>
```

続いて、以下のコマンドで対象PodのDeploymentを削除します。

```Bash
kubectl delete deployment test-deployment -n <namespace名>
```

以下のコマンドでDeployment及びPodが削除されたことを確認します。

```Bash
kubectl get deployments -n <namespace名>
kubectl get pod -n <namespace名>
```

### 2.6 Tips

先ほどまではDeployment Manifestを作成しPodを作成しましたが、簡単なテストを実行したい場合などに手軽にPodを起動したい場合などがあると思います。
以下のようなコマンドを実行すると、ワンライナーでPodの起動までが行えます。

```Bash

kubectl run <Pod名> --image=<image名> 

```

また、Manifestを1から書くことが難しい場合は、以下のようにdry-runとyaml出力を組み合わせてファイルに書き込むことでサンプルファイルを作成することができます。


```Bash

kubectl run <pod名> --image=<image名> --dry-run=client -o yaml > <ファイル名>
```

## 3. オリジナルコンテナデプロイ (Secretの活用)

### 3.1. Deployment Manifestの修正

続いて、前回DockerHubにPushしたオリジナルのImageを使い
Podを作成していきます。

オリジナルPod用のmanifestを作成します。
manifest名は任意のもので構いません。

```Bash
vi hands-on-nginx.yaml
```

サンプルコードは以下です。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  labels:
    app: hello-world
  name: hello-world
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world
  template:
    spec:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - image: <DockerHubのユーザ名>/<リポジトリ名>:<タグ名>
        name: hands-on-nginx
        ports:
        - containerPort: 80
```

### 3.2. Deploymentの適用

デプロイを試みます。

```Bash
kubectl apply -f <manifest名.yaml> -n <namespace名>
```

以下のコマンドで確認すると、Podの作成が失敗していることがわかります。

```Bash
kubectl get pod -n <namespace名>
```

```Log
NAME                                  READY   STATUS         RESTARTS   AGE
hands-on-nginx-8f5b8f48c-xb9kx     0/1     ErrImagePull       0                 14s
```

このようなエラーが起こった場合は、原因の解析にPodの詳細出力が役立つ場合があります。
以下のコマンドを入力します。

```Bash
kubectl describe pod <pod名> -n <namespace名>
```

```Log
Name:             hands-on-nginx-8f5b8f48c-xb9kx
Namespace:        test1
Priority:         0
Service Account:  default
Node:             ip-192-168-34-191.ap-northeast-1.compute.internal/192.168.34.191
Start Time:       Thu, 07 Dec 2023 05:08:14 +0000
Labels:           app=hands-on-nginx
                  pod-template-hash=8f5b8f48c
Annotations:      <none>
Status:           Pending
IP:               192.168.49.0
IPs:
  IP:           192.168.49.0
Controlled By:  ReplicaSet/hands-on-nginx-8f5b8f48c
Containers:
  hands-on-nginx:
    Container ID:   
    Image:          ryuichitakei/hands-on:hands-on-nginx
    Image ID:       
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Waiting
      Reason:       ImagePullBackOff
    Ready:          False
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-4wdf2 (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
Volumes:
  kube-api-access-4wdf2:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason     Age                  From               Message
  ----     ------     ----                 ----               -------
  Normal   Scheduled  2m23s                default-scheduler  Successfully assigned test1/hands-on-nginx-8f5b8f48c-xb9kx to ip-192-168-34-191.ap-northeast-1.compute.internal
  Normal   Pulling    52s (x4 over 2m22s)  kubelet            Pulling image "ryuichitakei/hands-on:hands-on-nginx"
  Warning  Failed     51s (x4 over 2m21s)  kubelet            Failed to pull image "ryuichitakei/hands-on:hands-on-nginx": rpc error: code = Unknown desc = failed to pull and unpack image "docker.io/ryuichitakei/hands-on:hands-on-nginx": failed to resolve reference "docker.io/ryuichitakei/hands-on:hands-on-nginx": pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed
  Warning  Failed     51s (x4 over 2m21s)  kubelet            Error: ErrImagePull
  Warning  Failed     37s (x6 over 2m20s)  kubelet            Error: ImagePullBackOff
  Normal   BackOff    25s (x7 over 2m20s)  kubelet            Back-off pulling image "ryuichitakei/hands-on:hands-on-nginx"
```
### 3.3. Secretの追加

上記のログから、最終的にImageのPullに失敗しErrorになっているのがわかります。
この原因は、格納されているリポジトリがプライベート設定であることです。
外部公開されていないイメージをPullしたい場合は、Secretと呼ばれる認証情報を格納するためのリソース指定が必要です。

現状、それぞれのNameSpaceにはSecretリソースが存在しないことを確認します。

```Bash
kubectl get secret -n <namespace名>
```

```
No resources found in  <namespace名> namespace.
```

今回はそれぞれのnamespaceにPodをデプロイする想定なので、namespace毎に認証情報が必要です。namespaceから外のリソースは互いに干渉しないため、それぞれのnamespace内でのみ認証情報の共有が有効となります。
今回のケースでは、ImageをPullする際にこのSecretを使うようManifestに指示を書くことでプライベートリポジトリからもImageのPullが可能になります。


以下のコマンドでSecretを作成します。

```Bash
kubectl create secret docker-registry <secret名> --docker-username=<DockerHubのユーザ名> --docker-password=<Dockerhubのパスワード> -n <namespace名>
```

### 3.4. SecretをDeploymentで利用

先ほどのManifestに、Secretに関する指示を追記します。

```Bash
vi hands-on-nginx.yaml
``` 

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  labels:
    app: hands-on-nginx
  name: hands-on-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hands-on-nginx
  template:
    spec:
    metadata:
      labels:
        app: hands-on-nginx
    spec:
      containers:
      - image: ryuichitakei/hands-on:hands-on-nginx # タグ名を自身のImageのものに変更
        name: hands-on-nginx
        ports:
        - containerPort: 80
      imagePullSecrets: # 追記
      - name: <secret名> # 追記
```

先ほど作成したPodの設定を更新します。

```Bash
kubectl apply -f hands-on-nginx.yaml -n <namespace名>
```

ImageのPullが成功し、Podが起動しているはずです。

```Bash
kubectl get pod -n <namespace名>
```

## 4. ReplicaSetの仕組み

ReplicaSetは稼働しているPod数を明示的に指定し、それを維持するためのリソースです。
2.アプリケーションデプロイの章でも体感していただきましたが、指定したReplica数を維持するために
自動的にPodの作成、削除が行われます。
現在、みなさんのManifestにはReplica数1が設定されています。
そのため、起動しているPodも1つになっているはずです。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  labels:
    app: hands-on-nginx
  name: hands-on-nginx
spec:
  replicas: 1 # ここが1に設定されている
  selector:
    matchLabels:
      app: hands-on-nginx
  template:
    spec:
    metadata:
      labels:
        app: hands-on-nginx
    spec:
      containers:
      - image: ryuichitakei/hands-on:hands-on-nginx 
        name: hands-on-nginx
        ports:
        - containerPort: 80
      imagePullSecrets: # 追記
      - name: <secret名> # 追記
```

では以下のようにManifestを修正し、再度Manifestを登録しなおしてみます。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  labels:
    app: hands-on-nginx
  name: hands-on-nginx
spec:
  replicas: 2 # 修正
  selector:
    matchLabels:
      app: hands-on-nginx
  template:
    spec:
    metadata:
      labels:
        app: hands-on-nginx
    spec:
      containers:
      - image: ryuichitakei/hands-on:hands-on-nginx 
        name: hands-on-nginx
        ports:
        - containerPort: 80
      imagePullSecrets:
      - name: <secret名>
```

```Bash
kubectl apply -f hands-on-nginx.yaml -n <namespace名>
```

Podが2つに増えているか確認します。

```Bash
kubectl get pod -n <namespace名>
```

> 出力例

```Log
NAME                              READY   STATUS    RESTARTS      AGE
hands-on-nginx-65f87b65fb-mx7n8   1/1     Running   0             9s
hands-on-nginx-65f87b65fb-wlvvw   1/1     Running   0             8s
```

## 5. Podの外部公開

続いて、Podの外部公開の方法を紹介します。
前回のセッションではPortForwardを使ってPodのアクセスを行いましたが


### 5.1. Service Manifestの作成

では、ManifestファイルからServiceを作成していきます。

```Bash
vi hands-on-nginx-service.yaml
```

以下のサンプルコードを参考にyamlファイルを作成します。

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: hands-on-nginx-service
  name: hands-on-nginx-service
  namespace: <namespace名> 
spec:
  ports:
  - nodePort: 32001 # Port番号を設定(重複しないように注意)
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: hands-on-nginx # 公開したいPodのラベル名
  sessionAffinity: None
  type: NodePort # ServiceTypeをNodePortにする
```

設定したラベルについては以下で確認が可能です。

```Bash
kubectl get pod -n <namespace名> --show-labels
```

### 5.2. Service Manifestの適用

作成したManifestを使ってServiceを作成します。

```Bash
kubectl apply -f hands-on-nginx-service.yaml -n <namespace名>
```

作成したServiceは以下で確認が可能です。

```Bash
kubectl get service -n <namespace名>
```

> 出力例

```Log
NAME                     TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
hands-on-nginx-service   NodePort   10.100.108.144   <none>        80:32001/TCP   44m
```

### 5.3. Service 通信確認

続いて、NodeのグローバルIP＋設定したNodePortのポート番号でアクセス確認を行います。

現在、２つのNodeに振り分けられてるIPをお伝えします。

どちらのIPで接続しても、ポート番号が正しければ適切なPodに通信を割り振ってくれるので
自身が作成したHTMLコンテンツが表示されるはずです。

```Bash
curl http://＊＊＊＊:32001
<!DOCTYPE html>
<html lang="ja">
  <style>
    body {
      margin: 0;
    }

    .center-me {
      display: flex;
      justify-content: center;
      align-items: center;
      /*font-family: 'Saira Condensed', sans-serif;*/
  font-family: 'Lobster', cursive;
      font-size: 100px;
      height: 100vh;
    }
  </style>  
<head>
    <meta charset="utf-8">
      <title>Test</title>
  </head>
  <body>
    <div class="center-me" >
    <p>
      <h1>Hello World!!🙂</h1>
    </p>
  </div>
  </body>
</html>
```

## 6. Ingressとアプリケーションの更新

このセクションでは、Podを外部公開するためのリソースであるIngressと、Kubernetesが持つPodの更新方法について紹介します。

### 6.1. Rolling Update

Kubernetesには、Podを別のイメージに変更したりバージョンを更新する際に、サービスに影響が出ないよう段階的に更新の動作を行うRolling Updateという機能があります。

それでは、実際に更新動作を確認していきましょう。
更新するときの処理はstrategy で指定します。デフォルトはRollingUpdateです。
ローリングアップデートの処理をコントロールするためにmaxUnavailableとmaxSurgeを指定することができます。

- minReadySeconds
  新しく作成されたPodが利用可能となるために、最低どれくらいの秒数コンテナーがクラッシュすることなく稼働し続ければよいか
- maxSurge
  理想状態のPod数を超えて作成できる最大のPod数(割合でも設定可)
- maxUnavailable
  更新処理において利用不可となる最大のPod数(割合でも設定可)


今回は4つのReplica数に対して25%、つまり1つずつ更新がかかるような設定をしています。
また、Podは作成後直ぐに利用可能になるので、動作イメージをつかみやすくするためにminReadySecondsは10秒に設定しています。



動作確認用のManifestを適用しましょう。

```
kubectl apply -f rollout.yaml
```

続いて、ブラウザで以下にアクセスを行います。

```
http://rollout.example.com
```

Pod更新前の状態では、`This app is Blue`の画面が表示がされていると思います。


続いて、先ほどデプロイしたDeplpymentに対して、イメージの更新を行います。


その際、Rolling Updateの機能が働き、25%のPod数(1個)ずつ追加されていく様子が確認できます。

```Bash
# 適用
kubectl set image deployment/rolling rolling-app=ryuichitakei/green-app:1.0

# 確認
kubectl rollout status deployment 
kubectl rollout history deployment 
kubectl get pod
kubectl get deployment

```

更新後、ブラウザで再度以下にアクセスを行うと`This app is Green`の表示に更新されていることが確認できます。

```
http://rollout.example.com
```

尚、ロールバックを行う場合は以下のコマンドで実行可能です。

```Bash
kubectl rollout undo deployment rolling
```

動作確認実施後、リソースの削除を行います。

```Bash
kubectl delete deployment rolling
kubectl delete service rolling
lubectl delete ingress rolling
```

### 6.2 Blue-Green Deployment


古い環境と新しい環境を混在させ、ルーティングなどによってトラフィックを制御し、ダウンタイム無しで環境を切り替えます。
今回はIngressのHost名によって、新旧どちらのアプリケーションにもアクセスできるような環境を用意しています。


まずは、対象のManifestを適用します。

```
kubectl apply -f 
```



## 7. データの永続化 (PVとPVC)

ここまでのハンズオンで、コンテナの特性がある程度見えてきたかと思います。
おさらいすると、以下のような特性があります。

- カーネルを持たず、プロセスのような振る舞いをする
- 起動・停止がVMに比べて高速で行える
- データを自身で持たずエフェメラルな存在として扱う。

上記の特性から、コンテナのデータをどう扱う(システムとしてどう設計する)かは非常に重要な観点です。
このセクションでは、外部ストレージ(今回はEFS)にコンテナをマウントさせ、データの永続化が確認できるまでのテストを行います。


### 7.1. PVの作成

PV(Persistent Volume)は外部ストレージとの接続を司るリソースです。
以下がPVを作成するためのサンプルコードです。
claimRef以下のnamespaceとnameに関しては6.2で作成するPVCの情報を入力します。

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: <任意の名前>
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  claimRef:
    namespace: <自身のNamespace>
    name: <自身のPVC名>
  storageClassName: efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: fs-086edefd664db607d
```

### 7.2. PVCの作成

PVC(Persistent Volume Claim)は、PodのVolumeに関する要求事項を定義するためのリソースです。

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <任意の名前>
  namespace: <自身のnamespace>
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
```

### 7.3. Podの作成

データの永続化を行うPodは、volumes属性に使いたいPVCの名前を書くことで作成できます。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: <任意の名前>
  namespace: <自身のnamespace>
spec:
  containers:
  - name: app1
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo $(date -u) >> /data/out1.txt; sleep 5; done"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: <自身のPVC名>
```

### 7.4. リソースの作成と動作確認

以下のコマンドで各リソースの作成を行います。

#### 7.4.1 PVの作成

```Bash
kubectl apply -f <pvのManifest>
```

#### 7.4.2 PVCの作成

```Bash
kubectl apply -f <pvcのManifest>
```

#### 7.4.3 Podの作成

```Bash
kubectl apply -f <podのManifest>
```

#### 7.4.4 動作確認

```
kubectl get pv
```

```
kubectl describe pv <pv名>
```

```
kubectl get pvc -n <自身のnamespace>
```

```
kubectl exec -ti volume-pod -- tail /data/out1.txt
```

### 8. 複数コンテナが動作するPod


PodはKubernetesにおける最小の単位ですが、その実態は複数(単独の場合もある)のコンテナで実行するリソースです。
例えば、Serice Meshを実現するためにネットワークプロキシとなるコンテナAとサービスアプリケーションとなるコンテナBを1つのPodとして稼働させることで、ネットワーク周りの処理をコンテナBに任せてコンテナはサービスの提供に全てのリソースを割くといったことができます。
以下のサンプルファイルを使って、複数コンテナのPodをデプロイしてみましょう。

```Yaml
  ---
apiVersion: v1
kind: Pod
metadata:
  name: multi-pod
spec:
  containers:
  - image: nginx
    name: alpha
    env:
    - name: name
      value: alpha
  - image: busybox
    name: beta
    command: ["sleep", "4800"]
    env:
    - name: name
      value: beta
```

### 9. ServiceAccountとUser Account

KubernetesにはPodにマッピングされるServiceAccountと、管理者もしくは開発者のkubectlの適用範囲を司るUser Accountの概念が存在します。
まずは、ServiceAccountを作成してPodが実行することができるコマンドの範囲が制御できることを確認してみましょう。


#### Service Accountの作成と動作確認

> ServiceAccount作成

```Bash
kubectl get serviceaccounts -n <ns名>
kubectl create serviceaccount <sa名> -n <ns名>
kubectl get serviceaccounts -n <ns名>
```

> Role作成

```Bash
kubectl get role -n <ns名>
kubectl create role <role名> --resource=pods --verb=get,watch,list -n <ns名>
kubectl get role -n <ns名>
```

> RoleBinding作成

```Bash
kubectl get rolebinding -n <ns名>
kubectl create rolebinding <rolebinding名> --role=<role名> --serviceaccount=<ns名>:<sa名> -n <ns名>
kubectl get rolebinding -n <ns名>
```

> Pod作成

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
        kubectl get pod
        sleep 30
      done
  serviceAccountName: <sa名>
```

> Podデプロイ

```Bash

kubectl apply -f kubectl-pod.yaml -n <ns名>

```

> ログからコマンドを実行していることを確認

```Bash
kubectl logs kubectl-pod -n <ns名>
```

> 一度Podを削除し、コマンドを変更して再デプロイ

```Bash

kubectl delete pod kubectl-pod -n <ns名>

```

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
  serviceAccountName: <sa名>
```

```Bash

kubectl apply -f kubectl-pod.yaml -n <ns名>

```

> ログからコマンドが弾かれていることを確認

```Bash
kubectl logs kubectl-pod -n <ns名>
```

>確認できたらPodを削除
```Bash

kubectl delete pod kubectl-pod -n <ns名>

```

#### User Accountの作成と動作確認

続いてUserの作成を行います。
User Accountは厳密にはK8sのリソースとして定義されておらず、getでも確認ができません。
しかしながら、APIとマッピングしてkubectlの適用範囲を明示的に制御することができます。
まずはUser Accountを作成するために秘密鍵とCSRを作成し、それを元にUser Accountを作成します。
続いて、User Accountに紐づくRoleとRole Bindingを作成し、動作確認を行います。

> 秘密鍵とCSRの作成

```
openssl genrsa -out <pem名>.pem 2048
openssl req -new -key <pem名>.pem -out <csr名>.csr -subj "/CN=<任意のCN>"
```

> csrをbase64にエンコード

```
cat <csr名>.csr | base64 | tr -d '\n'
```

> UserAccount作成

```Yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: <UserAccount名>
spec:
  signerName: kubernetes.io/kube-apiserver-client
  request: <base64でエンコードしたテキストを貼り付ける>
  usages:
  - client auth
```

```Bash
kubectl apply -f <manifest名> 
```

> CSRをApprove


```Bash
kubectl get csr
kubectl certificate approve <UserAccount名>
kubectl get csr
```

> Role作成

```Bash
kubectl get role -n <ns名>
kubectl create role <role名> --resource=pods --verb=create,list,get,update,delete --namespace=<ns名>
kubectl get role -n <ns名>
```

> RoleBinding作成

```Bash
kubectl get rolebinding -n <ns名>
kubectl create rolebinding <rolebinding名> --role=<role名> --user=<user名> --namespace=<ns名>
kubectl get rolebinding -n <ns名>
```
> 動作確認

リソース名などを変えてみて、yes or noの出力を確かめます。

```Bash
kubectl auth can-i update pods --as=<User名> --namespace=<ns名>
```

### 10. トラブルシュート

これまで学習してきたことを活用して、トラブルシュートを行ってみましょう。
各Namespaceに壊れたPodをデプロイしました。原因を調査し、Podをrunningステータスにしてください。


> ヒント

- discribeコマンドを使う
- logsコマンドを使う
- editもしくは-o yamlをファイルに書き出して再デプロイ


### 11. おまけ(jsonpath)

jsonpathは、ワンライナーで欲しい情報のみを引き抜く際に便利な機能です。
jsonpathでNodeの内部IPのみをファイルに書き出してみましょう。

```Bash
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' > <ファイルのPathとファイル名>
```

## 12. Readiness/Liveness Probe

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

### 12.1 Readiness Probe

今回は`/tmp/ready`ファイルの有無によって、Podの準備が出来ているかを判断するシナリオです。
まずは対象のファイルを作成しない状態でPodをデプロイしてみます。


```Bash
kubectl apply -f readiness-pod.yaml
```

対象のファイルが作成されていない状態ではPodがReadyのステータスにならないことがわかります。

```
kubectl get pod
```

```
NAME                    READY   STATUS    RESTARTS      AGE
readiness-pod           0/1     Running   0             7s
```


続いてreadiness-pod.yamlを以下のように編集して、コンテナ内に対象のファイルを作成するようにします。


```Yaml
  - command:
    - sh
    - -c
    - touch /tmp/ready && sleep 1d
```


再度Podの状態を確認すると、状態がReadyになっていることが確認できます。


```
NAME                    READY   STATUS    RESTARTS      AGE
readiness-pod           1/1     Running   0             7s
```



### 12.2 Liveness Probe


続いて、Liveness Probeの動作確認を行います。







## 13. Network Policy


```
kubectl apply -f netpol-pod.yaml
```

```
kubectl get pod -o wide -L app | grep app
```

```
kubectl exec -it nginx-app1 -- curl -I <PodのIP>
```

```
kubectl apply -f default-deny-all.yaml
```

```
kubectl exec -it nginx-app1 -- curl -I <PodのIP>
```

```

```

## JobとCronJob

### Job

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

```
completion: 6
parallelism: 2
```

以下のManifestを適用します。

```
kubectl apply -f handson-job.yaml
```

動作確認は以下のコマンドで行います。

```
kubectl get job
```

以下のように、完了したJobは`COMPLETIONS`としてカウントされていきます。

```
NAME          COMPLETIONS   DURATION   AGE
handson-job   6/6           15s        58s
```

また、Podの挙動を観察することで動作確認をすることも可能です。
以下のコマンドで2つずつ並列でJobが実行されていくのが確認できます。

```
watch -n 1 kubectl get pod
```

実際のJobの実行結果はLogを確認します。

```
kubectl logs <Pod名>
```

確認が完了したらリソースを削除します。


```
kubectl delete job handson-job
```

### Cron　Job

Cron Jobは、リソース内のCronに従って、スケジュールされた時間にJobを実行します。
Cron Jobは、先ほど実行したJobの上位リソースに当たります。

今回は1分ごとにJobを動作させるシナリオです。
それでは、前回のJobのシナリオ同様にManifestをapplyして動作を確認していきましょう。

```
kubectl apply -f handson-cronjob.yaml
```

1分ごとにJobが増えていくのが確認できます。

```
watch -n 1 kubectl get pod
```

今回はdateコマンドを実行するJobなので、日付が出力されているはずです。

```
kubectl logs <Pod名>
```

以下のコマンドはCron Jobのステータスや詳細が確認できます。

```
kubectl get cronjob

kubectl describe cronjob　handson-cronjob

```

Cron Jobを一時停止したい場合は、kubectl patchコマンドを使用します。
リソース内の`spec.suspend`パラメータを`true`にすることで停止が可能です。

`kubectl get cronjob`を実行すると、現在は`SUSPEND`が`False`になっていることが確認できます。

```
NAME              SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
handson-cronjob   */1 * * * *   False     0        24s             7m24s
```

以下のコマンドを実行します。

```
kubectl patch cronjob handson-cronjob -p '{"spec":{"suspend":true}}'
```

実行後、以下のようにステータスが変更されていることが確認できます。

```
NAME              SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
handson-cronjob   */1 * * * *   True      0        8s              13m
```

動作確認後、リソースを削除します。


```
kubectl delete cronjob handson-cronjob
```

