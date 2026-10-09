# KubeVirt
本chapterではKubernetesクラスタ上で仮想マシンを動作させるKubeVirtを体験し、コンテナワークロードと仮想化ワークロードの統合管理について学習します。


- [KubeVirt](#kubevirt)
  - [概要](#概要)
    - [KubeVirtとは](#kubevirtとは)
    - [KubeVirtの特徴](#kubevirtの特徴)
    - [アーキテクチャ](#アーキテクチャ)
  - [セットアップ](#セットアップ)
    - [KubeVirtのインストール確認](#kubevirtのインストール確認)
    - [virtctl CLIの確認](#virtctl-cliの確認)
  - [仮想マシンの作成と管理](#仮想マシンの作成と管理)
    - [最初の仮想マシンを作成](#最初の仮想マシンを作成)
    - [仮想マシンへの接続](#仮想マシンへの接続)
    - [仮想マシンの操作](#仮想マシンの操作)
      - [仮想マシンの停止](#仮想マシンの停止)
      - [仮想マシンの再起動](#仮想マシンの再起動)
      - [仮想マシンの削除](#仮想マシンの削除)
  - [Fedora仮想マシンの作成](#fedora仮想マシンの作成)
    - [Fedora仮想マシンのデプロイ](#fedora仮想マシンのデプロイ)
    - [仮想マシンの起動と接続](#仮想マシンの起動と接続)
  - [ネットワーク設定](#ネットワーク設定)
    - [仮想マシン用サービスの作成](#仮想マシン用サービスの作成)
  - [データボリュームとPersistentVolume](#データボリュームとpersistentvolume)
    - [データボリューム付き仮想マシンの作成](#データボリューム付き仮想マシンの作成)
    - [ライブマイグレーション](#ライブマイグレーション)
  - [KubeVirtの監視](#kubevirtの監視)
    - [仮想マシンのメトリクス確認](#仮想マシンのメトリクス確認)
    - [仮想マシンの詳細情報](#仮想マシンの詳細情報)
  - [最終クリーンアップ](#最終クリーンアップ)


## 概要
### KubeVirtとは

KubeVirt は、Kubernetes上で仮想マシンを動作させるためのKubernetes拡張機能です。
これにより、コンテナワークロードと仮想化ワークロードを同一のKubernetes環境で統合して管理できるようになります。

### KubeVirtの特徴

- **ハイブリッド環境の実現**: コンテナと仮想マシンを同一のKubernetesクラスタで管理
- **Kubernetesネイティブ**: Kubernetes APIを使用した仮想マシンの管理
- **リソース管理**: Kubernetesのリソース管理機能（CPU、メモリ、ストレージ）を仮想マシンにも適用
- **スケジューリング**: Kubernetesのスケジューラーが仮想マシンの配置も管理
- **ライブマイグレーション**: 仮想マシンのライブマイグレーション機能

![kubevirt](./image/kubevirt-architecture.png)

### アーキテクチャ

KubeVirtは以下の主要コンポーネントで構成されています：

- **virt-operator**: KubeVirtのライフサイクルを管理
- **virt-api**: VirtualMachineやVirtualMachineInstanceのAPI server
- **virt-controller**: 仮想マシンの状態を管理するコントローラ
- **virt-handler**: 各ノードで動作し、仮想マシンの実際の管理を行う
- **virt-launcher**: 個々の仮想マシンを実行するPod

## セットアップ

KubeVirtは以下のコマンドでインストールします：

 ```sh
 export RELEASE=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)

 # 1. KubeVirt Operatorのインストール
 kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-operator.yaml

 # 2. KubeVirt CRのインストール
 kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-cr.yaml

 # 本環境ではネスト仮想化するために以下設定を追加
 kubectl -n kubevirt patch kubevirt kubevirt --type=merge --patch '{"spec":{"configuration":{"developerConfiguration":{"useEmulation":true}}}}'

 # 3. インストール確認
 kubectl wait --for=condition=Ready pods -l kubevirt.io=virt-operator -n kubevirt --timeout=300s

 # 4. virtctl CLIのインストール
 curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/virtctl-${RELEASE}-linux-amd64
 chmod +x virtctl
 sudo mv virtctl /usr/local/bin

```

### virtctl CLIの確認

KubeVirtの仮想マシン操作には`virtctl`コマンドを使用します。
バージョンを確認して正常にインストールされていることを確認します。

```sh
virtctl version

Client Version: version.Info{GitVersion:"v1.8.2", GitCommit:"3203e9d1ce77af32f6a9ce72b9f954830666f72c", GitTreeState:"clean", BuildDate:"2026-04-20T14:34:03Z", GoVersion:"go1.24.9 X:nocoverageredesign", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{GitVersion:"v1.8.2", GitCommit:"3203e9d1ce77af32f6a9ce72b9f954830666f72c", GitTreeState:"clean", BuildDate:"2026-04-20T16:50:30Z", GoVersion:"go1.24.9 X:nocoverageredesign", Compiler:"gc", Platform:"linux/amd64"}
```

### KubeVirtのインストール確認

まずは、KubeVirtが正常にインストールされているか確認します。

```sh
kubectl get pods -n kubevirt

以下のようなPodが実行されているはずです：

NAME                               READY   STATUS    RESTARTS   AGE
virt-api-c7557fd74-7lqtr           1/1     Running   0          4m51s
virt-api-c7557fd74-hsmd6           1/1     Running   0          4m51s
virt-controller-5677985698-dsdnb   1/1     Running   0          4m3s
virt-controller-5677985698-rp9c9   1/1     Running   0          4m3s
virt-handler-2xcbq                 1/1     Running   0          4m3s
virt-handler-ffhfn                 1/1     Running   0          4m3s
virt-operator-86d97799c8-g6xgm     1/1     Running   0          5m38s
virt-operator-86d97799c8-jb4dc     1/1     Running   0          5m38s
```

## 仮想マシンの作成と管理

### 最初の仮想マシンを作成

シンプルなCirros（軽量なLinux OS）仮想マシンを作成します。

```sh
kubectl apply -f manifest/cirros-vm.yaml
```

作成された仮想マシンの状態を確認します：

```sh
kubectl get vms
```

```log
NAME        AGE   STATUS    READY
cirros-vm   30s   Stopped   False
```

仮想マシンを起動します：

```sh
# 以下コマンドいずれかを実行
virtctl start cirros-vm

kubectl patch virtualmachine cirros-vm --type merge -p '{"spec":{"runStrategy": "Always"}}'
```

起動後の状態を確認：

```sh
kubectl get vms
kubectl get vmis
kubectl get po
```

- **VM（VirtualMachine）**: 仮想マシンの定義と望ましい状態を保持するリソースで、停止・起動してもオブジェクトは永続します。
- **VMI（VirtualMachineInstance）**: 実際に稼働中の仮想マシンインスタンスを表すリソースで、仮想マシンが起動している間のみ存在します。

### 仮想マシンへの接続

仮想マシンのコンソールに接続します：

```sh
virtctl console cirros-vm
```

ログイン情報：
- ユーザー: `cirros`
- パスワード: `gocubsgo`

ログイン後、仮想マシン内で以下コマンドを実行してみてください。

```sh
$ uname -o -a
Linux cirros-vm 4.4.0-28-generic #47-Ubuntu SMP Fri Jun 24 10:09:13 UTC 2016 x86_64 GNU/Linux
```

コンソールから抜ける場合は `Ctrl + ]` を使用します。

### 仮想マシンの操作

#### 仮想マシンの停止

```sh
# 以下コマンドいずれかを実行
virtctl stop cirros-vm

kubectl patch virtualmachine cirros-vm --type merge -p '{"spec":{"runStrategy": "Halted"}}'
```

VMが停止したことを確認し、VMIが削除されていることを確認します。

```sh
kubectl get vms
kubectl get vmis
```



#### 仮想マシンの再起動

```sh
# 再度VMを起動し、再起動を実行
virtctl start cirros-vm
virtctl restart cirros-vm

# VMが再起動される過程を確認
kubectl get vms -w
```

#### 仮想マシンの削除

```sh
kubectl delete vm cirros-vm
```

## Fedora仮想マシンの作成

### Fedora仮想マシンのデプロイ

より実用的なFedora仮想マシンを作成します：

```sh
kubectl apply -f manifest/fedora-vm.yaml
```

### 仮想マシンの起動と接続

```sh
virtctl start fedora-vm
virtctl console fedora-vm
```

※起動には5分ほど時間がかかります。

ログイン情報：
- ユーザー: `fedora`
- パスワード: `password`


以下、コマンドを実行し
```sh
cat /etc/redhat-release
# 以下のようにFedoraのVMが稼働していることを確認
Fedora release 32 (Thirty Two)

```

## ネットワーク設定

### 仮想マシン用サービスの作成

仮想マシンにSSH接続できるようにServiceを作成します：

```sh
# 以下コマンドいずれかを実行
kubectl apply -f manifest/vm-service.yaml

virtctl expose vm fedora-vm --name fedora-svc --port 22 --target-port 22
```

ポートフォワードによる接続

```sh
kubectl port-forward service/fedora-svc 2222:22
```

別のターミナルからSSH接続：

```sh
ssh -p 2222 fedora@localhost
```

## データボリュームとPersistentVolume

### データボリューム付き仮想マシンの作成

DataVolumeはCDIが作成・管理する仮想マシン用ディスクイメージの取り込みリソースで、HTTPやPVCなどのソースから VM用の永続ディスクを自動生成できます。

CDI（Containerized Data Importer）はKubeVirt向けにデータのインポート・クローン・アップロードを提供するコンポーネントで、DataVolume の実体処理を担います。

ContainerDisk(前項までのやりかた)はコンテナイメージに同梱した一時的なルートディスクをそのまま使う方式で、CDI は外部ソースから永続ディスクを取り込み・複製して再利用可能なストレージとして運用します。

```sh
# CDIのインストール
export VERSION=$(basename $(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest))
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-operator.yaml
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-cr.yaml

kubectl get cdi cdi -n cdi
kubectl get pods -n cdi
```

永続化ストレージを使用する仮想マシンを作成します：

```sh
kubectl apply -f manifest/vm-with-datavolume.yaml

# 仮想マシンを起動します。
virtctl start vm-with-datavolume

# StorageClass が WaitForFirstConsumer の場合、
# 仮想マシンを起動しないと DataVolume の PHASE は
# WaitForFirstConsumer から進みません。

kubectl get datavolume
# 以下のようにDatavolumeがSucceededになると成功です。
# 今回DataVolumeではマニフェストの14行目にあるイメージをダウンロードしています。
NAME                PHASE       PROGRESS   RESTARTS   AGE
fedora-datavolume   Succeeded   100.0%                11m

kubectl get pvc
# Datavolumeのデータは以下のようにPVCを利用します
NAME                STATUS   VOLUME                                     CAPACITY      ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
fedora-datavolume   Bound    pvc-0b4df460-d2cc-49f0-812b-3abdec197649   11381663335   RWO            standard       <unset>                 11m
```

### ライブマイグレーション

ノード間で仮想マシンの移動を行います。
**本環境ではストレージの都合上、本項は実施できません。**
ライブマイグレーションの細かい制限については[公式ドキュメント](https://kubevirt.io/user-guide/compute/live_migration/#limitations)を参照ください。


```sh
virtctl start vm-with-datavolume
kubectl get vmi
virtctl migrate vm-with-datavolume

# 別のノードに仮想マシンが起動し直していることを確認
kubectl get vmi
```

## 最終クリーンアップ

全ての仮想マシンを削除：

```sh
kubectl delete vm --all
```
