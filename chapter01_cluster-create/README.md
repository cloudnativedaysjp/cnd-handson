# Kubernetesクラスターの作成

## はじめに

この章では以降の章で使用するKubernetesクラスターを作成します。

Kubernetesクラスターを作成する方法はいくつかありますが、今回のハンズオンでは、kindを利用してKubernetesクラスターを作成します。
構成としてはControl Plane 1台とWorker Node 2台の構成で作成します。
また、CNIとしてCiliumをデプロイします。
Ciliumの詳細は[Chapter4d Cilium](./../chapter04d_cilium/)にて説明します。

![](image/ch1-1.png)

まず、Kubernetesクラスターの構築に必要な下記ツールをインストールします。

- [kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/ja/docs/reference/kubectl/)
- [Cilium CLI](https://github.com/cilium/cilium-cli)
- [Helm](https://helm.sh/ja/)
- [Helmfile](https://github.com/helmfile/helmfile)

kindはDockerを使用してローカル環境にKubernetesクラスターを構築するためのツールになります。
また、kubectlはKubernetes APIを使用してKubernetesクラスターのコントロールプレーンと通信をするためのコマンドラインツールです。
Cilium CLIはCiliumが動作しているKubernetesクラスターの管理やトラブルシュート等を行うためのコマンドラインツールになります。
HelmはKubernetes用のパッケージマネージャーであり、Helmfileを使用することで宣言的にHelmチャートを管理できます。
各ツールの詳細については上記リンクをご参照ください。

上記のツールは`install-tools.sh`を実行することでインストールされます。

```shell
./install-tools.sh
```

> **Warning**  
> [Known Issue#Pod errors due to "too many open files"](https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files)に記載があるように、kindではホストのinotifyリソースが不足しているとエラーが発生します。
> ハンズオン環境ではinotifyリソースが不足しているため、sysctlを利用してカーネルパラメータを修正する必要があります。
> ```shell
> sudo sysctl fs.inotify.max_user_watches=524288
> sudo sysctl fs.inotify.max_user_instances=512
> ```
>
> また、設定の永続化を行うためには、下記のコマンドを実行する必要があります。
> ```shell
> cat << EOF >> /etc/sysctl.conf
> fs.inotify.max_user_watches = 524288
> fs.inotify.max_user_instances = 512
> EOF
> ```

構築するKubernetesクラスターの設定は`kind-config.yaml`で行います。
今回は下記のような設定でKubernetesクラスターを構築します。
- ホスト上のポートを下記のようにkind上のControl Planeのポートにマッピング
  -   80 -> 30080
  -  443 -> 30443
  - 8080 -> 31080
  - 8443 -> 31443
- CiliumをCNIとして利用するため、DefaultのCNIの無効化
- Ciliumをkube-proxyの代替として利用するため、kube-proxyの無効化

configオプションで`kind-config.yaml`を指定してKubernetesクラスターを作成します。

```shell
kind create cluster --config=kind-config.yaml
```

コマンドを実行すると以下のような情報が出力されます。

```shell
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
 ✓ Preparing nodes 📦 📦 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing StorageClass 💾 
 ✓ Joining worker nodes 🚜 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Not sure what to do next? 😅  Check out https://kind.sigs.k8s.io/docs/user/quick-start/
```

> **Info**  
> kubectlコマンドの実行時には、Kubernetesクラスターに接続するための認証情報などが必要になります。
> それらの情報は、kindでクラスターを作成した際に保存され、デフォルトで`~/.kube/config`に格納されます。
> このファイルに格納される情報は、kindコマンドを利用しても取得することが可能です
>
> ```shell
> kind get kubeconfig
> ```

最後に、下記のコンポーネントをデプロイします。

- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Cilium](https://cilium.io/)
- [Metallb](https://metallb.universe.tf/)
- [Nginx Ingress Controller](https://docs.nginx.com/nginx-ingress-controller/)

Gateway APIはKubernetesクラスター外からKubernetesクラスター内のServiceへのトラフィックを管理するためのものです。
Ciliumについては[Chapter4d Cilium](./../chapter04d_cilium/)で説明するのでそちらを参照してください。
MetallbはKind上のクラスターでServiceリソースのType:LoadBalancerを利用するためにインストールします。
Nginx Controllerはインターネットからのkind上のServiceリソースへ通信をルーティングするためにインストールします。
各コンポーネントの詳細については上記リンクをご参照ください。

まず、最初にGateway APIのCRDをデプロイします。

```shell
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.0.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.0.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.0.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.0.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.0.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
```

Gateway API以外のコンポーネントはhelmfileコマンドを利用することでデプロイできます。

```shell
helmfile sync -f hel
```

> **Info**  
> Kubernetesのイングレスコントローラーとして、Nginx Ingress Controllerをインストールしていますが、Cilium自体もKubernetes Ingressリソースをサポートしています。
> こちらに関しては、[Chapter4d Cilium](./../chapter04d_cilium/)にて説明します。

Metallbに関しては、追加で`IPAddressPool`と`L2Advertisement`をデプロイする必要があります。

```shell
kubectl apply -f manifest/metallb.yaml
```

> **Info**  
> manifest/metallb.yamlでデプロイしたIPAddressPoolリソースの`spec.addresses`に設定する値は、docker kindネットワークのアドレス帯から選択する必要があります。
> 今回は`manifest/metallb.yaml`既に設定済みのため意識する必要はありせんが、別環境でMetallbを設定するときには注意してください。
> 詳細は[Loadbalancer](https://kind.sigs.k8s.io/docs/user/loadbalancer/)を参照してください。

## Kubernetesクラスターへの接続確認

まずはKubernetesクラスターの情報が取得できることを確認します。

```shell
kubectl cluster-info
```

下記のような情報が出力されれば大丈夫です。

```shell
Kubernetes control plane is running at https://127.0.0.1:44707
CoreDNS is running at https://127.0.0.1:44707/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

> **Info**  
> [End-To-End Connectivity Testing](https://docs.cilium.io/en/stable/contributing/testing/e2e/#end-to-end-connectivity-testing)に記載があるように、Cilium CLIを利用することでEnd-To-Endのテストを行うこともできます。このテストは10分ほどかかります。
> ```shell
> cilium connectivity test
> ```

次に、次章以降で使用する動作確認用のアプリケーションをデプロイします。
動作確認用のアプリとしては、[Argo Rollouts Demo Application](https://github.com/argoproj/rollouts-demo)を使用します。
下記コマンドを実行することで、デプロイできます。

```shell
kubectl create namespace handson
kubectl apply -Rf manifest/app -n handson
```

ブラウザから`http://app.example.com`に接続し、下記のような画面が表示されることを確認してください。

![](./image/app-simple-routing.png)
