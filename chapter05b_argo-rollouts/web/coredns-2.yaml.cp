apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        hosts {
          133.242.235.81 app.rollout.com
          133.242.235.81 app-preview.rollout.com
          fallthrough
        }
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"Corefile":".:53 {\n    errors\n    health {\n       lameduck 5s\n    }\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n    }\n    prometheus :9153\n    hosts {\n      133.242.235.81 app.example.com\n      133.242.235.81 app-preview.example.com\n      fallthrough\n    }\n    forward . /etc/resolv.conf {\n       max_concurrent 1000\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}\n"},"kind":"ConfigMap","metadata":{"annotations":{},"creationTimestamp":"2023-10-08T08:57:46Z","name":"coredns","namespace":"kube-system","resourceVersion":"5104526","uid":"6bbe5ca4-7615-4167-bea7-bf5a98b55a71"}}
  creationTimestamp: "2023-10-08T08:57:46Z"
  name: coredns
  namespace: kube-system
  resourceVersion: "5109872"
  uid: 6bbe5ca4-7615-4167-bea7-bf5a98b55a71
