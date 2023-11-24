# 事前準備

**12/8に実施されているハンズオンに参加される方はこのステップは不要です。**

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
