# Chapter01 Cluster-Create

この章では以降の章で使用するKubernetesクラスターを作成します。

- ツールのインストール
- Kubernetesクラスターの作成
- Kubernetesクラスターへの接続確認

## ツールのインストール

下記のCLIツールをインストールします。

- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/ja/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux)
- [Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#cilium-quick-installation)

インストールするためのスクリプトが作成済みなので、`install-tools.sh`を実行するだけで上記のCLIツールがインストールされます。

```bash
./install-tools.sh
```

## Kubernetesクラスターの作成

今回のハンズオンではkindを利用しKubernetesクラスターを作成します。

> **Warning**  
> [Known Issue#Pod errors due to "too many open files"](https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files)に記載があるように、kindではinotifyリソースが不足していると、エラーが発生します。
> 今回のハンズオン環境ではinotifyリソースが不足しているため、下記のように設定を変更する必要があります。
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
- ホスト上のポートを下記のようにkind上のControl Planeのポートにマッピングします
  -   80 -> 30080
  -  443 -> 30443
  - 8080 -> 31080
  - 8443 -> 31443
- CiliumをCNIとして利用するため、DefaultのCNIの無効化
- Ciliumをkube-proxyの代替として利用するため、kube-proxyの無効化


下記のコマンドでKubernetesクラスターを作成します。

```bash
kind create cluster --config=kind-config.yaml
```

Kubernetesクラスターの作成後に、kubeconfigをホームディレクトリに保存しておきます。

```bash
mkdir -p ~/.kube
kind get kubeconfig > ~/.kube/config
```

最後に、CiliumとNginx Controllerをインストールします。

```bash
helmfile apply -f helmfile
```

> **Info**  
> CiliumもKubernetes Ingressリソースをサポートしています。
> こちらに関しては、[Chapter5d Cilium ServiceMesh](./../chapter05d_cilium-servicemesh/)にて説明します。

## Kubernetesクラスターへの接続確認

まずはKubernetesクラスターの情報が取得できることを確認します。

```bash
kubectl cluster-info
```

次に、Podを作成しアクセスできることを確認します。

下記のコマンドで、NginxのPodを起動します。

```bash
kubectl run --restart=Never nginx --image=nginx:alpine
kubectl port-forward nginx 8080:80
```

別のターミナルを開き、curlでアクセスできることを確認します。

```bash
curl localhost:8080
```

> **Info**  
> [End-To-End Connectivity Testing](https://docs.cilium.io/en/stable/contributing/testing/e2e/#end-to-end-connectivity-testing)に記載があるように、Cilium CLIを利用することでEnd-To-Endのテストも行うことができます。
> ```bash
> cilium connectivity test
> ```

