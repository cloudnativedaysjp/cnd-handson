# Dockerハンズオン


このセクションでは、Dockerを使ってコンテナアプリケーションの基本的な作成方法やdockerコマンドの使用方法を学びます。

## 1. コンテナ作成



まず、以下のコマンドでDockerの正常性確認を行います。



```Bash
docker version
# or
docker -v
```


> 出力結果例


```
Docker version 26.0.0, build 2ae903e
```


続いて、サンプルイメージをpullします。

このイメージはDocker社が作成したチュートリアルのWebアプリケーションです。


```
docker pull docker/getting-started
```


> 出力結果例


```
Using default tag: latest
latest: Pulling from docker/getting-started
df9b9388f04a: Pull complete 
5867cba5fcbd: Pull complete 
4b639e65cb3b: Pull complete 
061ed9e2b976: Pull complete 
bc19f3e8eeb1: Pull complete 
4071be97c256: Pull complete 
79b586f1a54b: Pull complete 
0c9732f525d6: Pull complete 
Digest: sha256:b558be874169471bd4e65bd6eac8c303b271a7ee8553ba47481b73b2bf597aae
Status: Downloaded newer image for docker/getting-started:latest
docker.io/docker/getting-started:latest
```


以下のコマンドで正常にPullができたか確認が行えます。


```Bash
docker image ls
# or
docker images
```


> 出力結果例


```
docker/getting-started                                  latest    cb90f98fd791   4 months ago    28.8MB
```


続いて、以下のコマンドでサンプルコンテナを起動します。

-dはバックグラウンド動作、-pはPortforwardの設定オプションです。


```Bash
docker run -d -p 8888:80 docker/getting-started
```

> 出力結果例


```
fe5facdead0cc4645abf79f477c44d8a5d99690e4478942e9c56cb7959fc5201
```


アクセス確認を行います。

正常にコンテナが起動できていれば、ステータスコード200が返却されるはずです。


```
curl -I localhost:8888
```


次に、コンテナを停止します。


コンテナを停止するにはコンテナIDが必要なため

以下のいづれかのコマンドで自身のコンテナIDを出力します。


```Bash
docker container ls | grep getting-atarted
# or
docker ps | grep getting-atarted
```

以下のコマンドでコンテナを停止します。

```
docker stop <container id> 
```



## 2.	Dockerfileからオリジナルコンテナを作成、DockerhubへPush


このセクションでは、Dockerfileと呼ばれるDocker Imageを作るための設定ファイルを作成して、実際にオリジナルのImageを作成します。

Imageの作成後は、DockerHubにPushを行います。


まず、以下のコマンドで作業ディレクトリを作成します。

ディレクトリ名は読み替えていただければ任意のもので構いません。


```Bash
mkdir hands-on
cd hands-on
pwd
```


続いて、任意のエディタでhtmlファイル作成します。

このhtmlファイルをDocker Imageの中に取り込み、オリジナルのコンテンツを表示させることが目的です。

以下はviを使用した例です。


```Bash
vi index.html
```


以下はサンプルコードです。
このままコピペでも構いませんが、後続のセクションで自身のコンテナが動作していることを認知しやすくするため、カスタムすることをお勧めします。


```HTML
<!DOCTYPE html>
<html lang="ja">
  <style>
    body {
      margin: 0;
    }

    .center-me {
      display: flex;
      justify-content: center;
      align-items: center;
      /*font-family: 'Saira Condensed', sans-serif;*/
  font-family: 'Lobster', cursive;
      font-size: 100px;
      height: 100vh;
    }
  </style>  
<head>
    <meta charset="utf-8">
      <title>Test</title>
  </head>
  <body>
    <div class="center-me" >
    <p>
      <h1>Hello World!!🙂</h1>
    </p>
  </div>
  </body>
</html>
```


続いて、Dockerfileを作成します。

タイトルは拡張子なし、先頭を大文字Dで作成します。


```Bash
vi Dockerfile
```


以下のようにファイルを編集します。
FROMはイメージの取得先、COPYはファイルを指定したディレクトリにコピー、RUNは指定したコマンドを実行するための記述です。


```Dockerfile
FROM nginx:latest
COPY index.html /usr/share/nginx/html/index.html
RUN service nginx start
```


続いて、作成したDockerfileを使ってimage buildを行います。

docker buildコマンドではPush先のリポジトリを指定し、任意のタグをつけることができます。

その際、タグ名はユニークなものを設定します。

今回は予め用意してあるhands-onリポジトリにImageをPushするため、以下のような指定方法となります。


```Bash
docker build -t ryuichitakei/hands-on:<任意のタグ名> .
```

以下のコマンドで、作成したDocker Imageをコンテナアプリケーションとして起動します。


```Bash
docker run -d -p 8888:80 ryuichitakei/hands-on:<任意のタグ名>
```


curlまたはブラウザを使ってアクセスすると、ご自身の作成したコンテンツが表示されるはずです。

```Bash
curl localhost:8888

```



確認後、以下のコマンドでコンテナを停止します。


```Bash
docker container ls
docker stop <container id> 
```


続いて、以下のコマンドでDocker HubにPushを行います。

今回は予め用意したプライベートリポジトリにimageをpushします。


```Bash
docker push ryuichitakei/hands-on:<任意のタグ名>
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
- マルチステージドビルドを使う
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
以下の2つのファイルを作成し、それぞれbuildしてください。


```bash
cd ..
mkdir -p multistaged/before/app ; cd multistaged/before 
vi Dockerfile
vi app/server.go
docker build --network host -t multistaged:before .
```

``` Dockerfile
# Dockerfile (multistaged:before)
FROM golang:1.19.3

WORKDIR /app
COPY ./app /app
RUN go mod init server \
        && go mod tidy \
        && go build -o server server.go
EXPOSE 1323
CMD [ "/app/server" ]
```

```Go
// app/server.go
// https://echo.labstack.com/guide/
package main

import (
	"net/http"
	
	"github.com/labstack/echo/v4"
)

func main() {
	e := echo.New()
	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Hello, World!")
	})
	e.Logger.Fatal(e.Start(":1323"))
}
```

```bash
cd ..
mkdir -p after/app ; cd after
vi Dockerfile
vi app/server.go
docker build --network host -t multistaged:after .
```

``` Dockerfile
# Dockerfile (multistaged:after)
# 
# Build
# 
FROM golang:1.19.3 AS stage

WORKDIR /app
COPY ./app /app
RUN go mod init server \
        && go mod tidy \
        && go build -o server server.go

# 
# Deploy
# 
FROM gcr.io/distroless/base-debian11

WORKDIR /app
COPY --from=stage /app/server /app/server
USER nonroot:nonroot
EXPOSE 1323
CMD [ "/app/server" ]
```

```Go
// app/server.go
// https://echo.labstack.com/guide/
package main

import (
	"net/http"
	
	"github.com/labstack/echo/v4"
)

func main() {
	e := echo.New()
	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Hello, World!")
	})
	e.Logger.Fatal(e.Start(":1323"))
}
```

それぞれのサイズを比較してみましょう。1GBほど縮小されていることがわかります。

```bash
docker images | grep multistaged
```


コンテナにアクセスしてどちらのアプリも応答することを確認してみましょう。

```bash
docker run --rm --name echo-after -p 1323:1323 -dit multistaged:after

curl http://localhost:1323/
```

コンテナを停止して、削除されたことを確認しましょう。
```bash
docker stop echo-after
docker ps -a
```

