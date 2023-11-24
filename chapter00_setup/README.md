# 事前準備

**12/8に実施されているハンズオンに参加される方はこのステップは不要です。**

## VM のセットアップ

演習で利用するVMに最低限のパッケージをインストールします。

```
sudo apt-get update
sudo apt-get install -y curl vim git unzip gnupg lsb-release ca-certificates dstat
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
```

## 名前解決の設定

今回の演習では、ローカル端末のhostsファイルを利用して名前解決を行います。

**Info**
> 利用しているOSに応じてhostsファイルに設定を書き込んでください。
> - Windows：`C:\Windows\System32\drivers\etc\hosts`
> - Linux: `/etc/hosts`

hostsファイルには、この演習を通して利用するIPアドレスとドメインの紐付けを設定してください。YOUR_HOST_IP_ADDRESSはこの演習で利用するマシンのIPアドレスを指定してください。

```
YOUR_HOST_IP_ADDRESS    app.example.com
YOUR_HOST_IP_ADDRESS    prometheus.example.com
YOUR_HOST_IP_ADDRESS    grafana.example.com
YOUR_HOST_IP_ADDRESS    jaeger.example.com
YOUR_HOST_IP_ADDRESS    argocd.example.com
YOUR_HOST_IP_ADDRESS    app.argocd.example.com
YOUR_HOST_IP_ADDRESS    dev.kustomize.argocd.example.com
YOUR_HOST_IP_ADDRESS    prd.kustomize.argocd.example.com
YOUR_HOST_IP_ADDRESS    helm.argocd.example.com
YOUR_HOST_IP_ADDRESS    app.argocd.example.com
YOUR_HOST_IP_ADDRESS    app-preview.argocd.example.com
YOUR_HOST_IP_ADDRESS    kiali.example.com
YOUR_HOST_IP_ADDRESS    app.cilium.example.com
YOUR_HOST_IP_ADDRESS    hubble.cilium.example.com
```
