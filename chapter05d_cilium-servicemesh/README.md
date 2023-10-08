# Service Mesh

Service Meshの機能と聞くと、以下の機能を期待されるかと思います。

- Observability
- Ingress
- L7 Traffic management
- Identity-based security

この機能うち、まずはIngressについて説明します。

## Ingress

CiliumはIngressのサポートをしており、Ciliumの機能でトラフィックのルーティングが可能です。
この節では、この章まではIngressとして利用してきたingress-nginxをCiliumに置き換えます。

まず、ingress-nginxおよびIngressリソースを削除します。

```bash
helm uninstall -n ingress-nginx ingress-nginx
kubectl delete ingress -A --all
```

次に、ingressControllerを有効にしたCiliumをアプライします。

```bash
helmfile apply -f helmfile
```

`ingressClassName`フィールドに`cilium`を設定したIngressをアプライすればIngressリソースを利用できます。

```bash
kubectl apply -f ingress.yaml
```

```bash
curl hubble.cilium.example.com
```


## 参考資料

- https://docs.cilium.io/en/stable/network/servicemesh/ingress/