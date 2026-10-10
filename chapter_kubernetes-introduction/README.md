# Kubernetes入門ハンズオン

## 1. 事前準備

まずは、CLIツールが正常に動作しているか確認します。
以下のコマンドを入力してください。

```sh
kubectl get nodes
```

Nodeの一覧が出力されるはずです。

```Log
NAME                 STATUS   ROLES           AGE   VERSION
kind-control-plane   Ready    control-plane   88m   v1.34.0
kind-worker          Ready    <none>          88m   v1.34.0
kind-worker2         Ready    <none>          88m   v1.34.0
```

Nodeが表示されない場合は、kubeconfigが設定されていない可能性があります。

以下のコマンドでkubeconfigの設定を確認します。

```sh
kubectl config get-contexts
```

```
# 実行結果
CURRENT   NAME        CLUSTER     AUTHINFO    NAMESPACE
*         kind-kind   kind-kind   kind-kind   
```


Kubernetesは、kubectlというCLIツールを提供しています。
kubectlは、ネットワークリーチャビリティのあるController NodeにAPIのリクエストを送ることで
リモートでの操作を可能にするものです。
正しくセットアップされていないとAPIリクエストを送ることができずに
Kubernetesの操作ができなくなってしまいます。

以下のコマンドでkubectlコマンドのバージョンの確認ができます。
```sh
kubectl version --client
```

```
# 実行結果
Client Version: v1.34.1
Kustomize Version: v5.7.1
```

続いて、chapter_kubernetes-introductionにcurrent directoryを移動します。

```sh
cd ~/cnd-handson-infra/chapter_kubernetes-introduction/
```

## 2. アプリケーションデプロイ

### 2.1. DeploymentをApply

続いて、簡単なテスト用アプリケーションをデプロイします。
Kubernetesでは、Manifestと呼ばれるファイルによって各リソースの状態が定義されます。
manifestファイルはyaml形式もしくはjson形式がサポートされています。
今回はyaml形式のmanifestを用意していますので、そのManifestを使ってPodをデプロイします。
以下のコマンドを入力してください。

```sh
cd manifests
kubectl apply -f test-deployment.yaml
```

以下のコマンドでPodの確認ができます。

```sh
kubectl get pods
```

### 2.2. ポートフォワードと通信確認

続いて、作成したPodにアクセスします。
今回はポートフォワードを使いpodにアクセスしていきます。

```sh
kubectl port-forward <Pod名>  8888:80
```

以下のように出力されたら操作が受け付けられなくなりますが、ctrl＋Cを押さずにそのままでいてください。

```Log
Forwarding from 127.0.0.1:8888 -> 80
Forwarding from [::1]:8888 -> 80
```

この時点でアクセスが可能になっているはずなので、新しくターミナルを開き、以下のコマンドでアクセスしてみましょう。

```sh
curl -I http://localhost:8888
```

成功すると、リターンコード200が返却されるはずです。

動作確認後、ctrl＋Cでポートフォワードを停止します。

### 2.3. Pod削除

続いて、Podを削除してみます。
以下のコマンドを入力してください。

```sh
kubectl delete pod <pod名>
```

Pod名、及び削除されたかどうかは以下で調べることができます。

```sh
kubectl get pods
```

上記の対応では、対象PodのRESTARTSのみがリセットされPodが削除できていないことがわかります。
Kubernetesはあるべき状態をManifestとして定義します。
このケースではPodを削除したことをトリガーにあるべき状態、つまり対象のPodが1つ存在する状態に戻そうと、Podの上位リソースであるReplicasetが働きかけたことが原因です。Replicasetはさらに上位リソースであるDeploymentによって管理されています。
従って、このようなケースでPodを完全に削除したい場合はDeploymentごと削除する必要があります。

まず、以下のコマンドでDeploymentの状態を確認します。

```sh
kubectl get deployments
```

続いて、以下のコマンドで対象PodのDeploymentを削除します。

```sh
kubectl delete deployment test
```

以下のコマンドでDeployment及びPodが削除されたことを確認します。

```sh
kubectl get deployments
kubectl get pods
```

### 2.4. Tips

先ほどまではDeployment Manifestを作成しPodを作成しましたが、簡単なテストを実行したい場合などに手軽にPodを起動したい場合などがあると思います。
以下のようなコマンドを実行すると、ワンライナーでPodの起動までが行えます。

```sh

kubectl run <Pod名> --image=<image名> 

```

また、Manifestを1から書くことが難しい場合は、以下のようにdry-runとyaml出力を組み合わせてファイルに書き込むことでサンプルファイルを作成することができます。

```sh

kubectl run <pod名> --image=<image名> --dry-run=client -o yaml > <ファイル名>
```


## 3. ReplicaSetの仕組み

ReplicaSetは稼働しているPod数を明示的に指定し、それを維持するためのリソースです。
2.アプリケーションデプロイの章でも体感していただきましたが、指定したReplica数を維持するために
自動的にPodの作成、削除が行われます。
先ほどのManifestにはReplica数1が設定されています。
そのため、起動たPodも1つだったはずです。

```Yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  labels:
    app: test
  name: test
spec:
  replicas: 1 #ここが1になっている
  selector:
    matchLabels:
      app: test
  template:
    spec:
      restartPolicy: OnFailure
    metadata:
      labels:
        app: test
    spec:
      containers:
      - image: nginx:latest
        name: test
        ports:
        - containerPort: 80
```

では以下のようにManifestを修正し、再度Manifestを登録しなおしてみます。

```Yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  labels:
    app: test
  name: test
spec:
  replicas: 2 #2に修正
  selector:
    matchLabels:
      app: test
  template:
    spec:
      restartPolicy: OnFailure
    metadata:
      labels:
        app: test
    spec:
      containers:
      - image: nginx:latest
        name: test
        ports:
        - containerPort: 80
```

```sh
kubectl apply -f test-deployment.yaml
```

Podが2つに増えているか確認します。

```sh
kubectl get pods
```

> 出力例

```Log
NAME                           READY   STATUS    RESTARTS   AGE
test-5cdf547c4f-8z5h9   1/1     Running   0          10s
test-5cdf547c4f-wvzbt   1/1     Running   0          10s
```

## 5. Podの外部公開

続いて、Podの外部公開の方法を紹介します。
前回のセッションではPortForwardを使ってPodのアクセスを行いましたが
本セクション以降はIngressというリソースを使って外部公開を行います。


### 5.1. Service/Ingressリソースの作成

では、Serviceを作成していきます。


以下のManifestが配置されていますので、それをapplyします。

```Yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: test
  name: test-service
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: test
  type: ClusterIP
```

```sh
kubectl apply -f test-service.yaml
```

Serviceについては以下で確認が可能です。

```sh
kubectl get services
```

> 出力例

```Log
test-service   ClusterIP   10.96.123.57   <none>        80/TCP    16s
```

続いてIngressリソースを作成します。
Serviceリソース同様、予め用意されているManifestを使用します。


```Yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: hello-world.example.com
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: test-service
            port:
              number: 80
```

```sh
kubectl apply -f test-ingress.yaml 
```

作成したIngressは以下で確認が可能です。

```sh
kubectl get ingress
```

> 出力例

```Log
NAME           CLASS   HOSTS                     ADDRESS        PORTS   AGE
test-ingress   nginx   hello-world.example.com   10.96.42.249   80      2m6s
```

### 5.2. 動作確認

続いて、ブラウザで以下にアクセス確認を行います。
Hello Worldの文字が表示されたら成功です。

```
 hello-world.example.com
```

動作確認後、リソースを削除します。

```
kubectl delete ingress test-ingress
kubectl delete service test-service
kubectl delete deployment test
```

## 6. アプリケーションの更新

このセクションでは、Kubernetesが持つPodの更新方法について紹介します。

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


今回は4つのReplica数に対してmaxSurgeを25%、つまり1つずつ更新がかかるような設定をしています。
また、Podは作成後直ぐに利用可能になるので、動作イメージをつかみやすくするためにminReadySecondsは10秒に設定しています。



動作確認用のManifestを適用しましょう。

```sh
kubectl apply -f rollout.yaml
```

続いて、ブラウザで以下にアクセスを行います。

```
http://rollout.example.com
```

Pod更新前の状態では、`This app is Blue`の画面が表示がされていると思います。


続いて、先ほどデプロイしたDeploymentに対して、イメージの更新を行います。


その際、Rolling Updateの機能が働き、25%のPod数(1個)ずつ追加されていく様子が確認できます。

```sh
# 適用
kubectl set image deployment/rollout rollout-app=ghcr.io/cloudnativedaysjp/green-app:1.0
```

```sh
# 確認
kubectl rollout status deployment 
kubectl rollout history deployment 
kubectl get pods
kubectl get deployments
```

更新後、ブラウザで再度以下にアクセスを行うと`This app is Green`の表示に更新されていることが確認できます。

```
http://rollout.example.com
```

尚、ロールバックを行う場合は以下のコマンドで実行可能です。

```sh
kubectl rollout undo deployment rollout
```

動作確認実施後、リソースの削除を行います。

```sh
kubectl delete deployment rollout
kubectl delete service rollout-service
kubectl delete ingress rollout-ingress
```

### 6.2 Blue-Green Deployment


古い環境と新しい環境を混在させ、ルーティングなどによってトラフィックを制御し、ダウンタイム無しで環境を切り替えます。
今回はIngressのHost名によって、新旧どちらのアプリケーションにもアクセスできるような環境を用意しています。

```Yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blue-green
spec:
  ingressClassName: nginx
  rules:
  - host: blue.example.com
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: blue-service
            port:
              number: 80
  - host: green.example.com
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: green-service
            port:
              number: 80
```

まずは、対象のManifestを適用します。

```sh
kubectl apply -f blue-green.yaml
```

続いて、Pod,Service,Ingressがそれぞれデプロイされているか確認を行います。


```sh
kubectl get pods,services,ingress
```

それぞれのリソースが正常に動作していることが確認できたら、ブラウザから以下のようにアクセスができるはずです。


```
http://blue.example.com → Blue App
http://green.example.com → Green App
```

動作確認実施後、リソースの削除を行います。

```sh
kubectl delete pod blue
kubectl delete pod green
kubectl delete service blue-service
kubectl delete service green-service
kubectl delete ingress blue-green
```

