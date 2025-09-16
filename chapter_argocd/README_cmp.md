# ArgoCDのConfig Management Plugins（CMP）入門 ～ArgoCDでHelmFileを利用してみよう～
ArgoCDはネイティブでHelm、Jsonnet,Kustomizeの三つのツールをサポートしていますが、HelmFileやその他のネイティブでサポートしていないツールを用いてマニュフェストを管理するために Config Management Plugin (CMP)と呼ばれるユーザが定義できるプラグインの仕組みが導入されています。
## argocd-repo-serverとSideCar
argocd-repo-serverは、クローンしたgitのレポジトリと同期して、マニュフェストを生成する機能を持っています。
CMPでは、argocd-repo-serverポッドにSideCarを追加し、
そのコンテナ内で必要なツール（Helmfile等）を実行してマニフェストを生成します。
図


## CMPにかかわるK8sリソース
1. **ConfigManagementPluginリソース**
   - CMPで実際に動かすコマンドや実行時の条件やパラメータを記述する
   - `discover`: どのファイルがある時にこのプラグインを使うかを定義
   - `init`: 前処理コマンド（依存関係の解決など）
   - `generate`: マニフェスト生成コマンド

2. **repoServerリソースのextraContainers**
   - CMPで利用するSideCarのコンテナの設定を記述する
   - 必要なツール（Helmfile等）がインストールされたイメージを使用


## CMPの適用方法～Patch編～
### plugin用のconfig mapの作成
CMPの処理を行う際のパラメータや実行処理を行うCMPのConfigMapの作成を行います
```
kubectl apply -f ./CMP/helmfile-cmp.yaml
```


### repo-serverへpatch
repo-serverで実際にCMP用のSideCarの設定をpatchとしてあてていきます。
```
kubectl patch deployment deployment.apps/argo-cd-argocd-repo-server --patch-file ./CMP/helmfile-cmp.yaml
```
## CMPの適用方法～HelmFile編～
### values.yamlにpulginの設定追加
helmfileのテンプレートは、CMPに対応しているのでvaluesに追記していきます。
```
cp ./CMP/values.yaml ./helm/values.yaml
```
valuesの中身を適用していきます。
```
helmfile sync -f helm/helmfile.yaml
```

## CMPで管理する
WEB UI,CLI,YAMLを利用して実際にPrometheusのチャプターを実際に作成してみてください。

### WEBUI
### CLI
### YAML
```
argocd apply -f ./CMP/application.yaml
```

### 結果を見てみよう
HelmFile経由でリソースが作成されることが確認できたら成功です！！