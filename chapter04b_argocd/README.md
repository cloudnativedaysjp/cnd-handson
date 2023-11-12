# chapter04b_argocd
この章では、Kubernetes上でGitOpsを可能とするCDツールであるArgo CDについて紹介し、導入します。

## GitOpsとCI/CDについて
CI/CDは、継続的インテグレーション（CI）と継続的デリバリー/デプロイメント（CD）を実現するための手法です。
CIは、アプリケーションのビルド、テスト、およびコードの統合を自動化するプロセス
CDは、アプリケーションのデプロイメントを自動化するプロセスです。
テストやデプロイを自動化することで、オペミスや作業量を減らすことで余ったリソースでアリケーションやソフトウェアの品質を高めたり、リソースサイクルを早めることを目的としている。

GitOpsは、CI/CDを実現するための手法の一つで、Gitのリポジトリの変更をトリガーにCI/CDを実行することで、アプリケーションのデプロイメントを自動化するプロセスです。


## Argo CDについて 
Kubrnetes用のGitOpsツールで、Gitリポジトリに格納されたマニフェストをデプロイすることができる。WEB GUIとCLIの両方で操作することができ、アプリケーションやKuberenetesのリソースの状態を可視化し簡単に管理する事が可能になっています。
ArgoCDはGitHub等からのWebhookを受け取り、Gitリポジトリに格納されたマニフェストをデプロイすることができるため、開発者のコードPushやPRをトリガーにデプロイまで実行することができます。



### Argo CDのアーキテクチャ
![image](https://argo-cd.readthedocs.io/en/stable/assets/argocd_architecture.png)


Argo CDは三つのコアコンポーネントで構成されています。
- API Server
- Repository Server
- Application Controller



## OutOfSync/Synced
アプリケーションがGitリポジトリの定義と設定と一致しているかどうかを示すステータスです。
#### OutOfSync
Gitリポジトリとアプリケーションの状態が一致せず、アプリケーションに変更があったか、同期エラーが発生したことを示します。
#### Synced
Gitリポジトリとアプリケーションの状態が一致し、アプリケーションが期待どおりに機能していることを示します。

## Healthy/Degrated/Processing 
アプリケーションの状態を示す異なるステータスで、アプリケーションの健全性や動作状態をしめステータスです。
#### Healthy
アプリケーションのコンポーネントやサーバーが期待どおりに応答し、エラーや障害がない状態です。
#### Degrated
アプリケーションが完全に停止していないが、一部の問題が存在する状態です。
#### Processing
アプリケーションやサービスが現在、新しいリクエストやデプロイメントなどの操作を処理していることを示し"Healthy" または "Degraded" の状態に変わります。

## Refresh/Hard Refresh/Sync の違いについて
これらの三つの処理は、GitレポジトリとArgo CDの状態を同期させるための処理ですが細かな違い存在します。
#### Refresh
最新のGitのコードとRepository Server内にあるコードを比較し、差分を反映する。
Application Controllerによって要求され、通常の更新はデフォルトで3分ごとに行われる。
#### HardRefresh
HelmやKustomizeなどのコードから生成されたマニフェストをキャッシュしているマニフェストキャッシュをクリアし、新たにRefresh処理を行う操作です。これにより、マニフェストの変更の有無にかかわらず、マニフェストを再生成できます。
デフォルトで24時間ごとに、マニフェストキャッシュの有効期限が切れたときに行われる。
#### Sync
Kubernetes clusterに変更を反映する事で、アプリケーションをGitリポジトリの状態に同期させる処理です。

## セットアップ
### ローカル環境での準備
今回デプロイするWEBサービスのドメインは登録していないため、WEBサービスを利用する際にはハンズオンで利用する端末のhostsファイルを書き込む必要があります。

hostsファイルのpathはOSによって様々なので環境によって変わりますが主要なpathは以下の通りです
MacやLinuxの場合
```/etc/hosts```
Windowsの場合
```C:\Windows\System32\drivers\etc\hosts```

この章で利用するドメインは

* app.argocd.com
* app.argocd.com
* dev.kustomize.argocd.com
* prd.kustomize.argocd.com
* helm.argocd.com

### Argo CDのインストール
helmファイルを利用してArgo CDをインストールします。
```
helmfile apply -f helmfile.yaml
```
ingressをdeployして、Argo CDのWEB UIにアクセス出来るようにします。
```
kubectl apply -f ingress.yaml
```
http://argocd.example.com/
へアクセスします。
* ユーザ名: admin
* パスワード: 以下のコマンドをサーバ上で実行した値

```kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d```

以下のページにアクセス出来るか確認して下さい。
![とりあえず]()
### レポジトリの登録
* Settings - > Repositories と進み CONEECT REPOをクリック　![とりあえず]()
*  上の画面上で各項目を次のように設定
```
Choose you connection method: VIA HTTPS
Type: git
Project: default
Repository URL: https://github.com/cloudnativedaysjp/cndt2023-handson
Username (optional):username
password (optional):pass
```
* CONNECTをクリック　（以下のスクショのようになったら成功）![とりあえず]()


## Demo appのデプロイ
* Applicationsの画面において + NEW APPを押下
    
    ![スクリーンショット 2023-09-30 23.07.28.png](https://prod-files-secure.s3.us-west-2.amazonaws.com/6f42360d-ca2e-4040-8123-63d144c7a54f/e7b0c560-715f-4169-aad8-c417668dd070/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88_2023-09-30_23.07.28.png)

* 上の画面上で各項目を次のように設定します．
```
GENERAL
  Application Name: test
  Project Name: default
  SYNC POLICY: Manual
  SYNC OPTIONS: AUTO CREATE NAMESPACE [v]
  SOURCE
    Repository URL: https://github.com/cloudnativedaysjp/cndt2023-handson
    Revision: main
    Path: chapter04b_argocd/default
  DESTINATION
    Cluster URL: https://kubernetes.default.svc
    Namespace: test
```
* 設定できたら、CREATEをクリック　（うまくいくと以下のようになる）

![Untitled](https://prod-files-secure.s3.us-west-2.amazonaws.com/6f42360d-ca2e-4040-8123-63d144c7a54f/d4d7967f-64b8-4619-8d91-d329a5689c9e/Untitled.png)

![Untitled](https://prod-files-secure.s3.us-west-2.amazonaws.com/6f42360d-ca2e-4040-8123-63d144c7a54f/d28f2ca5-03d7-48fc-bb07-397a93b5c5b9/Untitled.png)

* ページ上部にある SYNCをクリック
* 無事デプロイされると以下のようになります．

![Untitled](https://prod-files-secure.s3.us-west-2.amazonaws.com/6f42360d-ca2e-4040-8123-63d144c7a54f/09874bf9-6aa8-4588-ae47-fc503b24aafe/Untitled.png)

* http://app.argocd.com/へアクセスして確認

![Untitled](https://prod-files-secure.s3.us-west-2.amazonaws.com/6f42360d-ca2e-4040-8123-63d144c7a54f/e820fda1-b17a-4746-a1d4-47b494dffe03/Untitled.png)
