# Docker


このセクションでは、Dockerを使ってコンテナアプリケーションの基本的な作成方法やdockerコマンドの使用方法を学びます。


## 1. コンテナ作成


まず、以下のコマンドでDockerの正常性確認を行います。


```sh
docker version
# or
docker -v
```


```
# 実行結果
Docker version 26.1.4, build 5650f9b
```

続いて、サンプルイメージをpullします。

このイメージはDocker社が作成したチュートリアルのWebアプリケーションです。


```sh
docker pull docker/getting-started
```


```
# 実行結果
Using default tag: latest
latest: Pulling from docker/getting-started
c158987b0551: Pull complete
1e35f6679fab: Pull complete
cb9626c74200: Pull complete
b6334b6ace34: Pull complete
f1d1c9928c82: Pull complete
9b6f639ec6ea: Pull complete
ee68d3549ec8: Pull complete
33e0cbbb4673: Pull complete
4f7e34c2de10: Pull complete
Digest: sha256:d79336f4812b6547a53e735480dde67f8f8f7071b414fbd9297609ffb989abc1
Status: Downloaded newer image for docker/getting-started:latest
docker.io/docker/getting-started:latest
```


以下のコマンドで正常にPullができたか確認が行えます。


```sh
docker image ls
# or
docker images
```


```
# 実行結果
REPOSITORY               TAG       IMAGE ID       CREATED         SIZE
kindest/node             <none>    9319cf209ac5   4 weeks ago     974MB
docker/getting-started   latest    3e4394f6b72f   17 months ago   47MB
```


続いて、以下のコマンドでサンプルコンテナを起動します。

-dはバックグラウンド動作、-pはPortforwardの設定オプションです。


```sh
docker run -d -p 8888:80 docker/getting-started
```


```
# 実行結果
fe5facdead0cc4645abf79f477c44d8a5d99690e4478942e9c56cb7959fc5201
```


アクセス確認を行います。

正常にコンテナが起動できていれば、ステータスコード200が返却されるはずです。


```sh
curl -I localhost:8888
```


```
# 実行結果
HTTP/1.1 200 OK
Server: nginx/1.23.3
Date: Wed, 12 Jun 2024 06:26:03 GMT
Content-Type: text/html
Content-Length: 8702
Last-Modified: Thu, 22 Dec 2022 20:49:18 GMT
Connection: keep-alive
ETag: "63a4c2ce-21fe"
Accept-Ranges: bytes
```


次に、コンテナを停止します。


コンテナを停止するにはコンテナIDが必要なため
以下のいずれかのコマンドで自身のコンテナIDを出力します。
実行結果の左端、例でいうと `d7ae9ab08bd5` がコンテナIDとなります。


```sh
docker container ls | grep getting-started
# or
docker ps | grep getting-started
```

```
# 実行結果
d7ae9ab08bd5   docker/getting-started   "/docker-entrypoint.…"   3 minutes ago    Up 3 minutes    0.0.0.0:8888->80/tcp, :::8888->80/tcp                                                                                                                                            vigorous_tharp
```

以下のコマンドでコンテナを停止します。

```sh
docker stop <container id> 
```



## 2.	Dockerfileからオリジナルコンテナを作成


このセクションでは、Dockerfileと呼ばれるDocker Imageを作るための設定ファイルを作成して、実際にオリジナルのImageを作成します。


まず、以下のコマンドで作業ディレクトリに移動します。


```sh
cd hands-on-app/hapter_docker
pwd
```


続いて、image buildを行います。

docker buildコマンドではPush先のリポジトリを指定し、任意のタグをつけることができます。

その際、タグ名はユニークなものを設定します。


KubernetesのセクションでプライベートリポジトリからImageをPullするシナリオがあります。


Kubernetesのハンズオンを実施される方はプライベートリポジトリ名を指定してください。


```sh
docker build -t <DockerHubのユーザ名>/<リポジトリ名>:<任意のタグ名> .
```

以下のコマンドで、作成したDocker Imageをコンテナアプリケーションとして起動します。


```sh
docker run -d -p 8888:80 <DockerHubのユーザ名>/<リポジトリ名>:<任意のタグ名>
```


curlまたはブラウザを使ってアクセスすると、ご自身の作成したコンテンツが表示されるはずです。

```sh
curl localhost:8888
```



確認後、以下のコマンドでコンテナを停止します。


```sh
docker container ls
```


```sh
docker stop <container id> 
```


## 3. Dockerfileのベストプラクティス

コンテナを作成するにあたって、Docker公式でもベストプラクティスが紹介されています。


https://docs.docker.jp/develop/develop-images/dockerfile_best-practices.html



この中で重要と思われる項目について抜粋して、簡単に補足説明します。


- 一時的なコンテナを作成

  
  コンテナは、可能な限り一時的（ephemeral）であるべきです。コンテナは停止と同時に破棄される一時的な環境とすることが求められます。これにより再現性を高めることに繋がります。(docker commitはNG)
  運用で必要となる永続的なデータやログなどはコンテナの外に保管するようにしましょう。

  
- .dockerignore で除外

  
  コンテナに不要なデータは.dockerignoreでイメージを作成する際の対象から除外することができます。特に機密情報(パスワードやAPIキーなど、認証情報)はコンテナに含まれないようにしましょう。


- マルチステージビルドを使う

  
  コンテナは最小のイメージとすることが望ましいです。マルチステージビルドを活用することで、ソースコードのコンパイル用ステージとコンパイル済みバイナリの実行用ステージなどを分けることができ、大幅にイメージサイズを縮小することができます。


- 不要なパッケージのインストール禁止

  
  脆弱性などの対象範囲を狭めることにもつながり、セキュリティが向上します。


- アプリケーションを切り離す

  
  各コンテナはただ１つだけの用途を持つように作成しましょう。


Docker公式では明記されていないものの、これまでのコンテナ利用実績からベストプラクティスをインターネット上で公開している企業もあります。Sysdig社のベストプラクティスは整理されていて参考としやすいため紹介します。


https://sysdig.jp/blog/dockerfile-best-practices/


その中でもいくつか重要と思われる項目について抜粋して、簡単に補足説明します。


- 不要な特権を避ける

  
  rootで実行すると危険です。コンテナでプログラムをroot (UID 0) として実行しないようにしましょう。DockerfileでもUSERを設定して別ユーザでプロセスを起動させるように記載します。


- 信頼できるベースイメージを使う

  
  信頼されていないイメージやメンテナンスされていないイメージの上にビルドすると、そのイメージの問題や脆弱性をすべてコンテナに継承してしまいます。


ハンズオンとして、マルチステージビルドを実施してみましょう。
before、afterディレクトリ配下のアプリをそれぞれbuildしてください。


```sh
cd ..
```

```
cd multistage/before 
```

```sh
docker build -t multistage:before .
```

```sh
cd ..
```

```sh
cd after
```

```sh
docker build -t multistage:after .
```

それぞれのサイズを比較してみましょう。1GBほど縮小されていることがわかります。

```sh
docker images | grep multistage
```


コンテナにアクセスしてどちらのアプリも応答することを確認してみましょう。

```sh
docker run --rm --name echo-before -p 1111:1323 -dit multistage:before
```

```sh
docker run --rm --name echo-after -p 2222:1323 -dit multistage:after
```

```sh
curl http://localhost:1111/
```

```sh
curl http://localhost:2222/
```


コンテナを停止して、削除されたことを確認しましょう。

```sh
docker stop echo-before
```

```sh
docker stop echo-after
```

```sh
docker ps -a
```

