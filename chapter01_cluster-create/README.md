# Chapter01 Cluster-Create

この章では以降の章で使用するKubernetesクラスターを作成します。

- 準備
- Kubernetesクラスターの作成
- Kubernetesクラスターへの接続確認

## 準備

この節では、Kubernetesクラスターの構築に必要な下記のツールをインストールします。

- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/ja/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux)
- [Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#cilium-quick-installation)

`install-tools.sh`を実行すると上記のツールがインストールされます。

```bash
./install-tools.sh
```

## Kubernetesクラスターの作成

今回のハンズオンではkindを利用し、Kubernetesクラスターを作成します。

> **Warning**  
> [Known Issue#Pod errors due to "too many open files"](https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files)に記載があるように、kindではinotifyリソースが不足しているとエラーが発生します。
> 今回のハンズオン環境ではinotifyリソースが不足しているため、下記のような設定変更を行う必要があります。
> ```bash
> sudo sysctl fs.inotify.max_user_watches=524288
> sudo sysctl fs.inotify.max_user_instances=512
>
> # To make the changes persistent
> cat <<EOF >> /etc/sysctl.conf
> fs.inotify.max_user_watches = 524288
> fs.inotify.max_user_instances = 512
> ```

kindは下記の設定でKubernetesクラスターの構築を行います。
- ホスト上のポートを下記のようにkind上のControl Planeのポートにマッピング
  -   80 -> 30080
  -  443 -> 30443
  - 8080 -> 31080
  - 8443 -> 31443
- CiliumをCNIとして利用するため、DefaultのCNIの無効化
- Ciliumをkube-proxyの代替として利用するため、kube-proxyの無効化


下記のコマンドでKubernetesクラスターを作成します。

```console
$ kind create cluster --config=kind-config.yaml
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
> kubectlコマンドの実行時にはKubernetesクラスターに接続するための認証情報などが必要になります。
> kindでクラスターを作成した際には、接続に必要な情報は`~/.kube/config`に格納されます。
> このファイルに格納される情報はkindコマンドを利用しても取得することが可能です
>
> ```console
> $ kind get kubeconfig
> ```

最後に、下記のコンポーネントをデプロイします。

- [Cilium](https://cilium.io/)
- [Metallb](https://metallb.universe.tf/)
- [Nginx Controller](https://docs.nginx.com/nginx-ingress-controller/)

```console
$ helmfile apply -f helmfile
```

> **Info**  
> Kubernetesのイングレスコントローラーとして、Nginx Controllerをインストールしていますが、Cilium自体もKubernetes Ingressリソースをサポートしています。
> こちらに関しては、[Chapter5d Cilium ServiceMesh](./../chapter05d_cilium-servicemesh/)にて説明します。

Metallbに関しては追加で`IPAddressPool`と`L2Advertisement`をデプロイします。

```console
kubectl apply -f metallb.yaml
```

> **Info**
> IPAddressPoolのspec.addressesに設定する値はdocker kindネットワークのアドレス帯から選択する必要があります。
> 詳細は[Loadbalancer](https://kind.sigs.k8s.io/docs/user/loadbalancer/)を参照してください。

## Kubernetesクラスターへの接続確認

まずはKubernetesクラスターの情報が取得できることを確認します。

```console
$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:44707
CoreDNS is running at https://127.0.0.1:44707/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

次に、Podを作成しアクセスできることを確認します。

下記のコマンドで、NginxのPodを起動します。

```console
$ kubectl run --restart=Never nginx --image=nginx:alpine
pod/nginx created
$ kubectl port-forward nginx 8081:80
Forwarding from 127.0.0.1:8081 -> 80
Forwarding from [::1]:8081 -> 80
```

別のターミナルを開き、curlでアクセスできることを確認します。

```console
$ curl localhost:8081
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

> **Info**  
> [End-To-End Connectivity Testing](https://docs.cilium.io/en/stable/contributing/testing/e2e/#end-to-end-connectivity-testing)に記載があるように、Cilium CLIを利用することでEnd-To-Endのテストも行うことができます。
> ```bash
> cilium connectivity test
> ```

