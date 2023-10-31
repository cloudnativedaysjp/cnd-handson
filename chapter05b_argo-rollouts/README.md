chapter05b_argo-rollouts

# Analysis
## JOB
Analysis実行時にjobをデプロイし、jobの実行結果によってPromteするかどうかを判断する
## WEB
Analysis実行時にリクエストを送信し、レスポンスの内容にてよってPromteするかどうかを判断する
* Json形式のレスポンスの場合Jsonの中身を見て判断することが可能
* Json形式以外のレスポンスの場合はstatus codeが200であるかどうかの判断になる

## Prometheus
Analysis実行時にPrometheusにPromQLを送信し、その結果によってPromteするかどうかを判断する

### 事前に準備が必要なもの
#### nginx-ingress 
```
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
--namespace ingress-nginx \
--set controller.metrics.enabled=true \
--set controller.metrics.serviceMonitor.enabled=true \
--set controller.metrics.serviceMonitor.additionalLabels.release="prometheus"
```


#### prometheus
```
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
--namespace prometheus  \
--set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
--set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
