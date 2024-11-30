# 事前準備

**実行委員主催のハンズオン企画でオンライン・オフライン参加される方はこのステップは不要です。事前に作成したVMを提供します。**

## VM の作成

下記の手順に従って、VMを作成してください。
今回はAWS環境のVMで実施していますが、他の環境でも基本的に動作する想定です。

```
# SSH で利用するキーペアの作成
aws ec2 create-key-pair  \
  --key-name cnd-handson-key \
  --key-type ed25519 \
  --query 'KeyMaterial' \
  --output text > cnd-handson-key.pem

# Security Groupの作成
aws ec2 create-security-group \
  --group-name cnd-handson-segcroup \
  --description "CND handson security group"

# Security Groupルールの更新
SECGROUP_ID=`aws ec2 describe-security-groups --group-names 'cnd-handson-segcroup' --query 'SecurityGroups[*].[GroupId]' --output text`
for PORT in 22 80 443 8080 8443 18080 18443 28080 28443; do
  aws ec2 authorize-security-group-ingress \
  --group-id ${SECGROUP_ID} \
  --protocol tcp \
  --cidr 0.0.0.0/0 \
  --port ${PORT}
done

# インスタンスの起動（Ubuntu 22.04 image update 20240701）
aws ec2 run-instances \
  --image-id ami-0162fe8bfebb6ea16 \
  --count 1 \
  --instance-type t2.xlarge \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50}}]' \
  --key-name cnd-handson-key \
  --security-group-ids ${SECGROUP_ID} \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cnd-handson-vm}]'

# インスタンスのIPアドレスの確認
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=cnd-handson-vm" \
  --query 'Reservations[*].Instances[*].PublicIpAddress' \
  --output text
```

出力されるインスタンスのIPアドレスは「名前解決の設定」の手順で`YOUR_VM_IP_ADDRESS`を置き換えて利用してください。

## VM のセットアップ

演習で利用するVMに最低限のパッケージをインストールします。

```
sudo apt-get update
sudo apt-get install -y curl vim git unzip gnupg lsb-release ca-certificates dstat jq
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
```

## 名前解決の設定

今回の演習では、ローカル端末のhostsファイルを利用して名前解決を行います。

> **Info**  
> 利用しているOSに応じてhostsファイルに設定を書き込んでください。
> - Windows：`C:\Windows\System32\drivers\etc\hosts`
> - Linux, Mac: `/etc/hosts`

hostsファイルには、この演習を通して利用するIPアドレスとドメインの紐付けを設定してください。YOUR_VM_IP_ADDRESSはこの演習で利用するマシンのIPアドレスを指定してください。

```
YOUR_VM_IP_ADDRESS    hello-world.example.com
YOUR_VM_IP_ADDRESS    rollout.example.com
YOUR_VM_IP_ADDRESS    blue.example.com
YOUR_VM_IP_ADDRESS    green.example.com
YOUR_VM_IP_ADDRESS    app.example.com
YOUR_VM_IP_ADDRESS    cndw-web.example.com
YOUR_VM_IP_ADDRESS    prometheus.example.com
YOUR_VM_IP_ADDRESS    grafana.example.com
YOUR_VM_IP_ADDRESS    jaeger.example.com
YOUR_VM_IP_ADDRESS    argocd.example.com
YOUR_VM_IP_ADDRESS    app.argocd.example.com
YOUR_VM_IP_ADDRESS    dev.kustomize.argocd.example.com
YOUR_VM_IP_ADDRESS    prd.kustomize.argocd.example.com
YOUR_VM_IP_ADDRESS    helm.argocd.example.com
YOUR_VM_IP_ADDRESS    app-preview.argocd.example.com
YOUR_VM_IP_ADDRESS    kiali.example.com
YOUR_VM_IP_ADDRESS    kiali-ambient.example.com
YOUR_VM_IP_ADDRESS    app.cilium.example.com
YOUR_VM_IP_ADDRESS    hubble.cilium.example.com
YOUR_VM_IP_ADDRESS    pyroscope.example.com
```

## リポジトリのClone

マニフェストなどをVMにも配置するために、VM上でリポジトリをCloneしておいてください。

```shell
git clone https://github.com/cloudnativedaysjp/cnd-handson.git
```
