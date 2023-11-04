# CNDT2023 handson repository

https://github.com/cloudnativedaysjp/cndt2023-handson

* **できれば継続的にアップデートできるように、ダウンロードして取得したファイルなどは所在をコメントするか、取得するスクリプトを置いておいてください！**
* 各自レビューなくマージしちゃって良いです。


## Ingress の利用方法

VM の hostPort > kind の cotainerPort > NodePort Service > ingress-nginx Pod の順に転送するように設定してあるため、

* Ingress リソースの作成

<details><summary>詳細（sample.example.com を追加する例）</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-ingress-by-nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: sample.example.com
    http:
      paths:
      - path: /path1
        pathType: Prefix
        backend:
          service:
            name: sample-ingress-svc-1
            port:
              number: 8888
  defaultBackend:
    service:
      name: sample-ingress-default
      port:
        number: 8888
  tls:
  - hosts:
    - sample.example.com
    secretName: tls-sample
```

* app 例

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: sample-ingress-svc-1
spec:
  type: NodePort
  ports:
  - name: "http-port"
    protocol: "TCP"
    port: 8888
    targetPort: 80
  selector:
    ingress-app: sample1
---
apiVersion: v1
kind: Pod
metadata:
  name: sample-ingress-apps-1
  labels:
    ingress-app: sample1
spec:
  containers:
  - name: nginx-container
    image: amsy810/echo-nginx:v2.0
---
apiVersion: v1
kind: Service
metadata:
  name: sample-ingress-svc-2
spec:
  type: NodePort
  ports:
  - name: "http-port"
    protocol: "TCP"
    port: 8888
    targetPort: 80
  selector:
    ingress-app: sample2
---
apiVersion: v1
kind: Pod
metadata:
  name: sample-ingress-apps-2
  labels:
    ingress-app: sample2
spec:
  containers:
  - name: nginx-container
    image: amsy810/echo-nginx:v2.0
---
apiVersion: v1
kind: Service
metadata:
  name: sample-ingress-default
spec:
  type: NodePort
  ports:
  - name: "http-port"
    protocol: "TCP"
    port: 8888
    targetPort: 80
  selector:
    ingress-app: default
---
apiVersion: v1
kind: Pod
metadata:
  name: sample-ingress-default
  labels:
    ingress-app: default
spec:
  containers:
  - name: nginx-container
    image: amsy810/echo-nginx:v2.0
```

</details>

* ローカルマシンの /etc/hosts にエントリを追加

<details><summary>詳細（sample.example.com を追加する例）</summary>

`133.242.235.81 sample.example.com` を /etc/hosts に追記

`133.242.235.81` は VM の IP Address です。

</details>

の2点を実施することで、Ingress 経由でアクセス可能になっています。

