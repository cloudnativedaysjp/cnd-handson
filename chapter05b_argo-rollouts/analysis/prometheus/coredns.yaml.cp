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
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        hosts {
           133.242.235.81 app.rollout.com
           133.242.235.81 app-preview.rollout.com
           133.242.235.81 prometheus.example.com
           fallthrough
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
      {"apiVersion":"v1","data":{"Corefile":".:53 {\n    errors\n    health {\n       lameduck 5s\n    }\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n    }\n    prometheus :9153\n    forward . /etc/resolv.conf {\n       max_concurrent 1000\n    }\n    hosts {\n       133.242.235.81 app.rollout.com\n       133.242.235.81 app-preview.rollout.com\n       fallthrough\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}\n"},"kind":"ConfigMap","metadata":{"annotations":{},"creationTimestamp":"2023-10-30T16:56:18Z","name":"coredns","namespace":"kube-system","resourceVersion":"5475887","uid":"4d23ff71-04d5-4149-800d-f6baaa06ee87"}}
  creationTimestamp: "2023-10-30T16:56:18Z"
  name: coredns
  namespace: kube-system
  resourceVersion: "5477968"
  uid: 4d23ff71-04d5-4149-800d-f6baaa06ee87
