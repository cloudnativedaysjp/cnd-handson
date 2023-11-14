# Chapter 1.5 デモアプリのデプロイ

## 構築手順

ingress + clusterIP + demoappが立ち上がる
```
kubectl create namespace handson
kubectl apply -Rf manifest -n handson
```
## 確認方法
みなさんが利用しているMacやWindowsのマシンのhostsファイルを修正しブラウザで確認
```
133.242.235.81　app.example.com
```

http://app.example.com

## クリーンアップ
```
kubectl delete -Rf manifest -n handson
kubectl delete namespace handson
```
