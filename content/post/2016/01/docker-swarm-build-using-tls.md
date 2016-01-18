---
Categories:
  - Docker Swarm
Tags:
  - Docker
  - Swarm
  - TLS
  - Terraform
date: 2016-01-18T20:00:00+09:00
title: TLS認証なDocker Swarmクラスタを構築 (docker-machineなしで)
---

TSL認証なSwarmクラスタはdocker-machineで構築すると、勝手に設定してくれて非常に楽だが、ホストのネットワークを事前に弄りたかったり、Terraformなどの他オーケストレーションツールを組み合わせたいときに、ちょっと融通がきかない。

なので、TSL認証を用いたDocker Swarmクラスタを**自力で**構築できるように、手順をまとめておきたい。また、docker-machineの代替として**Terraform**を使い、自動化できるようにしたい。

![Docker Swarm using TLS](/images/post/2016/01/docker-swarm-build-using-tls/eyecatch.png)


### 作業の流れ

概ね以下の様な流れでSwarmクラスタの構築を行う。基本的には、docker-machineで行われていることを模倣している。docker-machine自体ではサービスディスカバリの準備は行わないので、そこら辺の手順も残しておく。

![Overview](/images/post/2016/01/docker-swarm-build-using-tls/overview.svg)


#### [付録] SwarmクラスタをTerraformで構築するサンプル

今回の記事で行う作業をTerraformで自動化したものを、以下のリポジトリに置いておくので、ご参考までに。terraform.tfの`count`の値を弄ることで、指定数のノードを自動で作成するので、大量にノードが必要な場合に便利かも。



> GitHub: namikingsoft/sample-terraform-docker-swarm
> https://github.com/namikingsoft/sample-terraform-docker-swarm


### 事前準備

#### 必要なソフトウェアのインストール

作業で使うPC(またはホスト)に以下のDocker関連のソフトウェアをインストールしておく。

* docker (Engine)
* OpenSSL (Linux系やOSXなら、デフォルトで入っているはず)


#### DigitalOceanの登録とアクセストークンの取得

この記事の例では、ホストにDigitalOceanを使うが、AWSとかでも可能と思います。

https://www.digitalocean.com/  
登録後、管理画面からdocker-machineとの連携に必要なアクセストークンを発行できる。



### ノード用のホストを用意する

今回の例では、DigitalOceanでノードを２台用意して、Swarmクラスタの連携を確認した。

| Host | OS | Mem | IP (eth0) | IP (eth1) |
|:----|:----|:----|:----|:----|
| **swarm-node0** | ubuntu-15-10-x64 | 512MB | x.x.x.1 | y.y.y.1 |
| **swarm-node1** | ubuntu-15-10-x64 | 512MB | x.x.x.2 | y.y.y.2 |

##### 備考
* swarm-node0はマスターノードとして使う
* ホスト名(hostname)は別になんでもよい
* プライベートネットワークを有効にしておく
* eth0はグローバルネットワークに繋がるインタフェース
* eth1はプライベートネットワークに繋がるインタフェース



### 各ノードでConsulを動かす

Swarmクラスタのサービスディスカバリー(分散KVS)であるConsulを各ノードにインストールする。使わないでもSwarmクラスタは構築できるが、マルチホスト間でオーバーレイ・ネットワークを作れるようになったりと色々利点が多いので。(etcdやZookeeperでも構築可能)

![Swarm Structure](/images/post/2016/01/docker-swarm-build-using-tls/consul.svg)


#### swarm-node0にてConsulをサーバーモードで動かす
SSHでログインして作業を行う。

##### Consulインストール
```sh
# 必要なパッケージのインストール
apt-get install -y curl zip

# Consulインストール
cd /tmp
curl -LO https://releases.hashicorp.com/consul/0.6.1/consul_0.6.1_linux_amd64.zip
unzip consul_0.6.1_linux_amd64.zip
mv consul /usr/local/bin

# ConsulのWebUIを設置(任意)
curl -LO https://releases.hashicorp.com/consul/0.6.1/consul_0.6.1_web_ui.zip
unzip consul_0.6.1_web_ui.zip -d consul-webui
```

##### Consul起動
```sh
nohup consul agent \
  -server -bootstrap-expect=1 \
  -node=consul0 \
  -data-dir=/tmp/consul \
  --ui-dir=/tmp/consul-webui \
  -bind=$(
    ip addr show eth1 \
    | grep -o -e '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' \
    | head -n1
  ) \
  >> /var/log/consul.log &
```
１台構成のサーバーモードをWebUI付き(任意)で起動する。プライベートネットワークであるeth1のIPにバインドする。

#### swarm-node1にてConsulをクライアントモードで動かす
SSHでログインして作業を行う。インストール方法は同じなので割愛。

##### Consul起動
```sh
nohup consul agent \
  -join y.y.y.1 \
  -node=consul1 \
  -data-dir=/tmp/consul \
  --ui-dir=/tmp/consul-webui \
  -bind=$(
    ip addr show eth1 \
    | grep -o -e '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' \
    | head -n1
  ) \
  >> /var/log/consul.log &
```
swarm-node0のプライベートIPにジョインする。

#### メンバー確認
各ノードのConsulが連携できているかを確認する。

```sh
$ consul members

Node     Address            Status  Type    Build  Protocol  DC
consul0  y.y.y.1:8301   alive   server  0.6.1  2         dc1
consul1  y.y.y.2:8301   alive   client  0.6.1  2         dc1
```



### 各ノードにDockerをインストール

各ノードのSSHにて、以下のコマンドを実行する。

```sh
wget -qO- https://get.docker.com/ | sh
```

デーモン起動時の引数設定などは後ほど行う。




### TLS認証用の鍵を生成する

クライアント側(ローカルPC)で生成する。後ほど各ノードに必要なファイルを転送する。

#### CAの証明書を生成
```sh
openssl genrsa -out ca-key.pem 4096
openssl req -subj "/CN=ca" -new -x509 -days 365 -key ca-key.pem -out ca.pem
```

#### クライアントの秘密鍵と証明書を生成
```sh
# extfile
echo "extendedKeyUsage = clientAuth" >> extfile-client.cnf

# client cert
openssl genrsa -out key.pem 4096
openssl req -subj '/CN=client' -new -key key.pem -out client.csr
openssl x509 -req -days 365 -sha256 -in client.csr -out cert.pem \
  -CA ca.pem -CAkey ca-key.pem -CAcreateserial -extfile extfile-client.cnf
```

#### swarm-node0(master)の秘密鍵と証明書を生成
```sh
# extfile
echo "subjectAltName = IP:x.x.x.1" > extfile.cnf
echo "extendedKeyUsage = clientAuth,serverAuth" >> extfile.cnf

# server cert
openssl genrsa -out node0-key.pem 4096
openssl req -subj "/CN=node0" -new -key node0-key.pem -out node0.csr
openssl x509 -req -days 365 -sha256 -in node0.csr -out node0-cert.pem \
  -CA ca.pem -CAkey ca-key.pem -CAcreateserial -extfile extfile.cnf
```
Swarm Managerを動かすノードなので、clientAuthも設定しておく。subjectAltNameにグローバルIPを設定するので、CommonName(CN)は割と何でもよいが、ドメイン名があれば、それを設定するとよい。

#### swarm-node1の秘密鍵と証明書を生成
```sh
# extfile
echo "subjectAltName = IP:x.x.x.2" > extfile.cnf

# server cert
openssl genrsa -out node1-key.pem 4096
openssl req -subj "/CN=node1" -new -key node1-key.pem -out node1.csr
openssl x509 -req -days 365 -sha256 -in node1.csr -out node1-cert.pem \
  -CA ca.pem -CAkey ca-key.pem -CAcreateserial -extfile extfile.cnf
```
CommonName(CN)は任意。

#### TLS認証鍵を各ノードへアップロード
SFTPやSCPなどを使って、各ノードの`/etc/docker`[^1]あたりにアップロードする。

* swarm-node0
  * ca.pem
  * node0-cert.pem
  * node0-key.pem
* swarm-node1
  * ca.pem
  * node1-cert.pem
  * node1-key.pem

[^1]: TLS認証鍵の置き場所は任意。Dockerデーモン起動時の引数で指定する。



### 各ノードのDockerの設定を変更する

各ノードにSSHでログインして、設定を行う。

#### Dockerデーモン起動時の引数設定

##### swarm-node0
```sh
vi /lib/systemd/system/docker.service

# 変更前
ExecStart=/usr/bin/docker daemon -H fd://
# 変更後
ExecStart=/usr/bin/docker daemon \
  --tlsverify \
  --tlscacert=/etc/docker/ca.pem \
  --tlscert=/etc/docker/node0-cert.pem \
  --tlskey=/etc/docker/node0-key.pem \
  -H=0.0.0.0:2376a\
  --cluster-store=consul://localhost:8500 \
  --cluster-advertise=eth0:2376 \
  -H fd://
```

##### swarm-node1
```sh
vi /lib/systemd/system/docker.service

# 変更前
ExecStart=/usr/bin/docker daemon -H fd://
# 変更後
ExecStart=/usr/bin/docker daemon \
  --tlsverify \
  --tlscacert=/etc/docker/ca.pem \
  --tlscert=/etc/docker/node1-cert.pem \
  --tlskey=/etc/docker/node1-key.pem \
  -H=0.0.0.0:2376 \
  --cluster-store=consul://localhost:8500 \
  --cluster-advertise=eth0:2376 \
  -H fd://
```

##### 備考
* 変更後は見やすさのため複数行で書いているが、` \ `を消して1行ぶっ続けで記述する。
* この設定はUbuntu15.10の場合なので、他のOSの場合は`/etc/default/docker`の`DOCKER_OPTS`に引数を付け加えたりなど、やり方が違ってくると思うので、各々調節する。
* cluster-storeとcluster-advertiseの指定は、オーバーレイ・ネットワーク機能のためなので、使わない場合は特に指定しなくても、Swarmクラスタの動作は可能。


#### Docker再起動
```sh
service docker restart
```

#### TLS接続確認
ローカルPCから、TLS(TCP)でホストのDockerを利用できるか確認してみる。
```sh
# swarm-node0
docker --tlsverify \
  --tlscacert=ca.pem --tlscert=cert.pem --tlskey=key.pem \
  -H=x.x.x.1:2376 \
  version

# swarm-node1
docker --tlsverify \
  --tlscacert=ca.pem --tlscert=cert.pem --tlskey=key.pem \
  -H=x.x.x.2:2376 \
  version
```
ClientとServerのDockerバージョンが表示されれば、正しく設定できている。

また、以下の様な環境変数を設定することで、いちいちTLS認証鍵やIP指定をしなくても、普通にdockerコマンドが扱えるようになる。

```sh
export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="tcp://(dockerホストのIP):2376"
export DOCKER_CERT_PATH="/path/to/クライアント認証鍵があるディレクトリ"

docker version
```

`DOCKER_CERT_PATH`については、`~/.docker/`にクライアント認証鍵(ca.pem, cert.pem, key.pem)を設置すれば、省略可能。



### 各ノードでSwarmコンテナを動かす
各ノードにSSHでログインして、Swarmコンテナを起動させる。

#### swarm-node0
```sh
# Swarm Manager
docker run -d --name swarm-agent-master \
  -v /etc/docker:/etc/docker --net host \
  swarm manage --tlsverify \
    --tlscacert=/etc/docker/ca.pem \
    --tlscert=/etc/docker/server-cert.pem \
    --tlskey=/etc/docker/server-key.pem \
    -H tcp://0.0.0.0:3376 --strategy spread \
    --advertise x.x.x.1:2376 consul://localhost:8500

# Swarm Agent
docker run -d --name swarm-agent --net host \
  swarm join --advertise x.x.x.1:2376 consul://localhost:8500
```

#### swarm-node1
```sh
# Swarm Agent
docker run -d --name swarm-agent --net host \
  swarm join --advertise x.x.x.2:2376 consul://localhost:8500
```

#### 備考
* ネットワークのホストと共有する必要があるので、`--net host`を指定している。
* Swarm Managerで`/etc/docker`を共有Volume指定しているのは、TLS認証鍵の共有だけではなく、`/etc/docker/key.json`の共有のため。DockerユニークIDの識別に必要とのこと。


### 動作確認
クライアント側(ローカルPC)から、Swarmクラスタへの接続を試みる。

#### Swarm MasterにTLS接続
```sh
export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="tcp://x.x.x.1:3376"
export DOCKER_CERT_PATH="/path/to/クライアント認証鍵があるディレクトリ"
```
```sh
$ docker info

Containers: 3
Images: 2
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 2
 swarm-node0: x.x.x.1:2376
  └ Status: Healthy
  └ Containers: 2
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 513.4 MiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.2.0-16-generic, operatingsystem=Ubuntu 15.10, storagedriver=aufs
 swarm-node1: x.x.x.2:2376
  └ Status: Healthy
  └ Containers: 1
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 513.4 MiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.2.0-16-generic, operatingsystem=Ubuntu 15.10, storagedriver=aufs
CPUs: 2
Total Memory: 1.003 GiB
Name: swarm-node0
```

上のように、ノードが2つ接続されていることが確認できれば、Swarmクラスタの構築がうまく行えている。`DOCKER_HOST`のポート指定を`2376`ではなく、`3376`にすることで、dockerコマンドでSwarm関連の操作を行うことができる。

#### Swarmクラスタにコンテナを配置してみる
```sh
$ docker run -d --name container1 nginx
$ docker run -d --name container2 nginx
$ docker ps --format "{{.Names}}"

swarm-node1/container1
swarm-node2/container2
```
Swarm Masterのストラテジーが`spread`なので、各ノードにコンテナが分散配置される。
