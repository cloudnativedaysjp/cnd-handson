
このドキュメントは、CD(Countinuous Delivery)のハンズオン資料になります。  
ハンズオンのChapter_argocdにある、ArcoCDを利用して実施していきます。  
そのため、ArgoCDをインストールしていない場合には、以下サイトからインストールを実施してください。  
ArgoCDの詳細については、[こちら](https://github.com/cloudnativedaysjp/cnd-handson/blob/main/chapter_argocd/README_webui.md)を参照ください。  

# 今回利用するリポジトリの準備  
## Gitリポジトリの準備(ローカル環境)

Argo CDを利用するため、GitHubへPush等が必要となり、それをトリガーとして利用します。  
このハンズオンのリポジトリをforkし、準備します。

[cnd-handson-infra](https://github.com/cloudnativedaysjp/cnd-handson-infra)  
↑をクリックし、forkを実施していきます。  
実際には、その中の**chapter_cicd/apps/frontend**のアプリを利用してハンズオンしていきます。

**fork**をクリックをして、Create a new forkで、名前を指定して自分のリポジトリへforkさせます。  

![image](image/fork1.png)


![image](image/fork2.png)

**create fork**をクリックします。  
自分のリポジトリを確認し、cnd-handson-infraがforkされていることを確認します。  

![image](image/fork3.png)

ここからは、Argo CDの詳細については、[ArgoCD](https://github.com/cloudnativedaysjp/cnd-handson/blob/main/chapter_argocd/README_webui.md)が動作している前提で解説していきます。  
動作していない場合には、上記リンクからインストールを実施してください。  
Argo CDのWebGUIへログインできれば問題ないです。  

## Argo CDのWebページへログイン
Argo CDのWebページへログインし、先ほどForkしたリポジトリを同期させます。  

**左のタブのSetting**をクリックし、**Repositories**をクリックします。

![image](image/repository1.png)

**CONNECT REOP**をクリックします。

![image](image/repository2.png)

以下ように自分の設定あうように設定していきます。  

![image](image/repository3.png)

```
GENERAL
Choose your connection method: VIA HTTPS
Type: git
Project: default
Repository URL: https://github.com/自身のアカウント名/cnd-handson-infra
```
最後、**+ CONNECT REPO**をクリックします。  
うまく繋がると、CONNECTIOM STATUSが **Successful** になります。  

## FrontendアプリをArgo CD上にデプロイ
Frontendのデプロイを行い、Argo CDの一連の操作を行います。
**+ NEW APP**をクリックし、設定をしていきます。

![image](image/app_deploy1.png)

![image](image/app_deploy2.png)

```
GENERAL
  Application Name: cicd-demo
  Project Name: default
  SYNC POLICY: Manual
  SYNC OPTIONS: AUTO CREATE NAMESPACE [v]
  SOURCE
    Repository URL: https://github.com/自身のアカウント名/cnd-handson-infra
    Revision: main
    Path: chapter_cicd/apps/frontend
  DESTINATION
    Cluster URL: https://kubernetes.default.svc
    Namespace: cicd-namespace
```

設定できたら、**CREATE**をクリックして、下記の表示の通り、**MissingとOutofSync**であることを確認して下さい。
 

![image](image/apps1.png)

↑で作成したアプリの**SYNC**をクリックしてください。  
そして、**SYNCHRONIZE**をクリックしてください。
それにより正式にデプロイされます。  

![image](image/status1.png)

↑の赤枠クリックするとを詳細がみれます。
ステータスが**HealthyとSynced**になることを確認してください。

![image](image/status2.png)

![image](image/status3.png)

![image](image/app_ver1.png)

podのimageが、` - image: ghcr.io/cloudnativedaysjp/cnd-handson-app/frontend:latest`  
になっていることが確認できます。

---
## Frontendのアプリのデプロイが完了
Frontendのページへアクセスしてみます。  
`http://app.cicd.example.com/login`  
すると以下のログイン画面がでてきます。  

![image](image/applogin1.png)

※メールアドレス、パスワードは、任意で入力してください。
認証機能を今回は動かしていないため、メールアドレス/パスワードを  
適当な文字列を入力することでログインできるようにしています。  
その後、**ログイン**をクリック。

```
例
メールアドレス: a@a
パスワード: 12345
```

すると、以下の**青いバー**の画面が表示されます。  

![image](image/login1.png)

ここまでで、Frontendのアプリケーションが動作しているところまで確認できました。  
では、CD(Continuous Delivery)の部分の動作を確認していきます。  
今回は先ほどforkしたリポジトリを直接変更します。  

![image](image/repo1.png)

ここで最初に設定されているimageを新しいバージョンのアプリケーションへ変更します。  
` - image: ghcr.io/cloudnativedaysjp/cnd-handson-app/frontend:latest`  
を  
` - image: ghcr.io/cloudnativedaysjp/cnd-handson-app/frontend-v1:latest`  
に変更し、`Commit Changes`します。  

><注釈>
>ソフトウェアのVerupの場合以下のように、Version管理をしていく形が多いですが、  
このハンズオンでは、Frontendのアプリ自身を明示的に変更しているため、latest版で作成しています。  
` - image: ghcr.io/cloudnativedaysjp/cnd-handson-app/frontend:v1.0`   
` - image: ghcr.io/cloudnativedaysjp/cnd-handson-app/frontend:v1.1`  
  


![image](image/repo2.png)

ArgoCDの画面に戻り、この状態で既存で動いているFrontendの変更をKickします。  
**SYNC**をクリックして、**SYNCHRONIZE**をクリックします。  

![image](image/argo11.png)

![image](image/app_ver2.png)

podのimageが、` - image: ghcr.io/cloudnativedaysjp/cnd-handson-app/frontend-v1:latest`  
になっていること。

この状態で、新しく**Frontend**のアプリが更新されました。  
では、Frontendのページへアクセスしてみます。  
`http://app.cicd.example.com/login`  
先ほど同様に入力し、ログインします。  
すると、以下の**黒いバー**の画面が表示されます。  

![image](image/login2.png)

これで、Githubのリポジトリにあるファイルから新イメージへ設定変更し、　　
その変更がトリガーとなりアプリケーション更新されるというCD(Continuous Delivery)のハンズオンです。  

## まとめ

この章では、CD（継続的デリバリー）を、ArgoCDによるアプリケーションの初回デプロイ及び、バージョンアップするまでの簡単な流れを学びました。

> [!IMPORTANT]  
> - CDは、アプリケーションのデリバリーを自動化し、デリバリプロセスの統一化と品質向上に貢献します。
> - コンテナ化したアプリケーションのデプロイは、Gitリポジトリを信頼されたソースとすることで、一貫性のある構成管理とトレーサビリティが実現できます。
> - ArgoCDを活用することで、GitOpsの原則に従った宣言的な運用が可能となり、運用ミスの削減や迅速なリリースが期待できます。
> - Kubernetes環境を前提とした運用により、開発・ステージング・本番といった環境間の構成差分を最小限に抑えることができ、従来のVMベースの運用に比べて再現性や移植性が向上します。

