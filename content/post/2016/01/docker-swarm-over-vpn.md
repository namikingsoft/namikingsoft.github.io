---
Categories:
  - Docker Swarm
Tags:
  - docker
  - Swarm
  - VPN
  - SoftEther
date: 2016-01-22T02:30:00+09:00
title: クラウドとローカルをVPNでガッチャンコしたDockerネットワークを組んでみる
---

クラウド上で組んだDockerのオーバーレイネットワークの中に、屋内ファイアウォール内のマシンで組んでたDockerを参加させることができないか、試してみた。

### なぜに？ (余談)

例えば、[以前の記事](/post/2016/01/docker-swarm-spark/)のようにクラウドで組んだSparkクラスタを利用するために、Apache Zeppelin[^1]を使ってみたい。最初は、SSHトンネルやSocksプロキシで手軽にできないだろうかと色々やってみたが、Sparkは一方通行な通信ではなく、双方向な通信を行うため、クラウドからローカルのネットワークに直接アクセス(pingなど)できる必要があるようで、動作するには至らなかった。

![Zeppelin on Local](/images/post/2016/01/docker-swarm-over-vpn/zeppelin-local.svg)

Spark関連は基本的に同じネットワーク内で動かすのが前提の仕様なため、Swarmクラスタと同じネットワーク内に入れる必要があるが、Zeppelinは、

* 割りとメモリ食い(推奨4GBほど)のため、Sparkクラスタと同じホストでは、動かしたくない。かといって、専用のホストを用意するできるブルジョアではない。
* クラウドのSparkクラスタは使い終わったらすぐに破壊したいが、Zeppelinはnotebookや設定のデータを内部で持つため、作った後や消す前の同期が少し面倒。

なので、できれば、ローカルネットワーク内にZeppelinを持っておきたい。

![Zeppelin on Local Ideal](/images/post/2016/01/docker-swarm-over-vpn/zeppelin-local-ideal.svg)

[^1]: [Zeppelin](https://zeppelin.incubator.apache.org/)はWeb上からSparkの操作をインタラクティブに行えたり、結果をビジュアライズできたりする、ノートブック系Webアプリ



### この記事でやること

上のApache Sparkの例は置いといて、今回は取り急ぎクラウドとローカルを跨いだSwarmクラスタを構築して、Dockerオーバーレイネットワークの疎通確認を行いたい。検証のため、以下の図の様な構成を準備して、オーバーレイネットワークの疎通を確認する。

![Zeppelin on Local Ideal](/images/post/2016/01/docker-swarm-over-vpn/docker-swarm-over-vpn.svg)

##### 要点
* ローカル環境とクラウドのDockerをVPNを用いて、オーバーレイネットワークで繋ぎたい。
* VPN接続には、SoftEther VPN[^2]を使ってみる。
* ローカル側とクラウド側１台ずつ、Swarm Masterをレプリケーションした。
  * クラウドのみでも、Swarmクラスタとして機能させたかったため。
  * ローカルの作業用PCは、いちいちVPNに接続しなくても、Swarmクラスタを操作できるようにするため。

[^2]: TCP/IPベースのVPNで、動かしてみたら割とすんなり動作したので、これを使ってみた。PPTPdも試したが、[Ubuntu15.10で上手く動作しなかった](http://askubuntu.com/questions/621820/pptpd-failed-after-upgrading-ubuntu-server-to-15)ので、見送り



### 事前準備

#### 必要なソフトウェアのインストール

作業で使うPC(またはホスト)に以下のソフトウェアをインストールしておく。

* docker (バージョン1.9以上, オーバーレイネットワーク機能を使う)
* docker-compose (動作検証に使うだけなので任意)
* Virtualbox (vagrantを併用してもよい)

#### DigitalOceanの登録とアクセストークンの取得

登録後、管理画面からdocker-machineとの連携に必要なアクセストークンを発行できる。

https://www.digitalocean.com/



### ノード用のホストを用意する

今回の例では、DigitalOceanでノードを２台とローカルでVirtualbox１台を用意する。

| Type | Host | OS | Mem | VPNのIP |
|:----|:----|:----|:----|:----|
| DigitalOcean | **swarm-node0** | ubuntu-15-10-x64 | 512MB | 192.168.30.2 (手動) |
| DigitalOcean | **swarm-node1** | ubuntu-15-10-x64 | 512MB | 192.168.30.x (自動) |
| Vitualbox(local) | **swarm-local** | ubuntu-15-10-x64 | - | 192.168.30.y (自動) |

##### 備考
* swarm-node0はマスターノードとして使う
* ホスト名(hostname)は別になんでもよい
* プライベートネットワークは無効にしておく
* VPNのIPについては、VPN接続後に割り当てる。



### SoftEther VPN Serverを動かす

swarm-node0にSSHなどでログインして、作業を行う。

Linux版については、[SoftEther VPNのサイト](https://ja.softether.org/)からソースコードをダウンロードして、コンパイルする。後で自動化しやすいように、GUIやインタラクティブCUIを使わないように書いておく。

#### ダウンロード
```sh
# 必要なパッケージのインストール
apt-get install -y curl gcc make

# SoftEther VPN ソースのダウンロード
cd /usr/local/src
curl -LO http://jp.softether-download.com/files/softether/v4.19-9599-beta-2015.10.19-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.19-9599-beta-2015.10.19-linux-x64-64bit.tar.gz
tar xzf softether-vpnserver-v4.19-9599-beta-2015.10.19-linux-x64-64bit.tar.gz
```

#### コンパイルとインストール
```sh
# コンパイル
cd vpnserver
make i_read_and_agree_the_license_agreement

# PATH設定
export PATH="/usr/local/src/vpnserver:$PATH"
echo 'export PATH="/usr/local/src/vpnserver:$PATH"' >> /etc/profile
```

#### サービス登録と起動 (systemd)
```sh
# サービス登録
cat << EOS > /lib/systemd/system/vpnserver.service
[Unit]
Description=SoftEther VPN Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/src/vpnserver/vpnserver start
ExecStop=/usr/local/src/vpnserver/vpnserver stop

[Install]
WantedBy=multi-user.target
EOS

# 自動起動設定＆起動
systemctl enable vpnserver
systemctl start vpnserver
```

#### VPNサーバー設定

```sh
# 各種設定項目 (値は任意で決める)
export HUBNAME=cluster
export HUBPASS=password
export USERNAME=user
export USERPASS=something
export SHAREDKEY=sharedkey

# 仮想HUB作成
vpncmd localhost /SERVER /CMD HubCreate $HUBNAME \
  /PASSWORD:$HUBPASS && true

# SNAT＆DHCP有効化
vpncmd localhost /SERVER /HUB:$HUBNAME /PASSWORD:$HUBPASS /CMD \
  SecureNatEnable

# ユーザー登録
vpncmd localhost /SERVER /HUB:$HUBNAME /PASSWORD:$HUBPASS /CMD \
  UserCreate $USERNAME \
  /GROUP:none \
  /REALNAME:none \
  /NOTE:none

# ユーザーパスワード設定
vpncmd localhost /SERVER /HUB:$HUBNAME /PASSWORD:$HUBPASS /CMD \
  UserPasswordSet $USERNAME \
  /PASSWORD:$USERPASS

# IPsec VPN有効化
vpncmd localhost /SERVER /CMD \
  IPsecEnable \
  /L2TP:yes \
  /L2TPRAW:no \
  /ETHERIP:yes \
  /PSK:$SHAREDKEY \
  /DEFAULTHUB:$HUBNAME
```
VPN設定のリファレンスは以下を参照。  
https://ja.softether.org/4-docs/1-manual/6/6.4



### SoftEther VPN Clientを動かす

全てのノードにSSHなどでログインして、作業を行う。  
Serverと同じく、[SoftEther VPNのサイト](https://ja.softether.org/)からソースコードをダウンロードして、コンパイルする。

#### ダウンロード
```sh
# 必要なパッケージのインストール
apt-get install -y curl gcc make

# SoftEther VPN ソースのダウンロード
cd /usr/local/src
curl -LO http://jp.softether-download.com/files/softether/v4.19-9599-beta-2015.10.19-tree/Linux/SoftEther_VPN_Client/64bit_-_Intel_x64_or_AMD64/softether-vpnclient-v4.19-9599-beta-2015.10.19-linux-x64-64bit.tar.gz
tar xzf softether-vpnclient-v4.19-9599-beta-2015.10.19-linux-x64-64bit.tar.gz
rm softether-vpnclient-v4.19-9599-beta-2015.10.19-linux-x64-64bit.tar.gz
```

#### コンパイルとインストール
```sh
# コンパイル
cd vpnclient
make i_read_and_agree_the_license_agreement

# PATH設定
export PATH="/usr/local/src/vpnclient:$PATH"
echo 'export PATH="/usr/local/src/vpnclient:$PATH"' >> /etc/profile
```

#### サービス登録と起動 (systemd)
```sh
# サービス登録
cat << EOS > /lib/systemd/system/vpnclient.service
[Unit]
Description=SoftEther VPN Client
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/src/vpnclient/vpnclient start
ExecStop=/usr/local/src/vpnclient/vpnclient stop

[Install]
WantedBy=multi-user.target
EOS

# 自動起動設定＆起動
systemctl enable vpnclient
systemctl start vpnclient
```

#### VPNサーバー設定
```sh
# 各種設定項目 (基本的にはServerの値と合わせる)
ACCOUNT=private
NICNAME=vlan0
SERVER="(swarm-node0のグローバルIP):443"
HUBNAME=cluster
USERNAME=user
USERPASS=something

# クライアント管理へのリモートログインを無効
vpncmd localhost /CLIENT /CMD RemoteDisable

# NIC作成 (この例だと、vpn_vlan0というインタフェースが作成される)
vpncmd localhost /CLIENT /CMD NicCreate $NICNAME

# アカウント作成
vpncmd localhost /CLIENT /CMD AccountCreate $ACCOUNT \
  /SERVER:$SERVER \
  /HUB:$HUBNAME \
  /USERNAME:$USERNAME \
  /NICNAME:$NICNAME

# アカウントパスワード設定
vpncmd localhost /CLIENT /CMD AccountPasswordSet $ACCOUNT \
  /PASSWORD:$USERPASS \
  /TYPE:standard

# アカウント自動起動設定
vpncmd localhost /CLIENT /CMD AccountStartupSet $ACCOUNT

# アカウント接続
vpncmd localhost /CLIENT /CMD AccountConnect $ACCOUNT

# swarm-node0では固定IP割り当て
ip addr add 192.168.30.2/24 dev vpn_$NICNAME

# その他ノードは自動割り当て
dhclient vpn_$NICNAME
```
swarm-node0だけは、DHCPでIPを振らずに固定IPを設定する。

#### VPN接続確認
SoftEther VPNのClientのセッティングが完了すると、以下の様な成果が出る。

* 各ノードに`vpn_vlan0`というインタフェースができる。
  * vpn_vlan0を通して、pingなどの疎通ができるようになる。
* 各ノードに192.168.30.0/24のネットワークのIPが割り当てられる。
  * 192.168.30.0/24はSoftEther VPNのデフォルト設定。
  * DHCPで割り当てると、192.168.30.10〜が振られる。

これから設置するConsulやDockerは、このネットワークにのせるように設定する。



### 各ノードでConsulを動かす

インストールとサービス登録手順については、[以前の記事](/post/2016/01/docker-swarm-build-using-tls#各ノードでconsulを動かす:357fa4bd2e644c21db7997b0a9ea5cf8)にまとめてあるので参照されたい。ここではConsulサーバーの設定手順を示す。

#### swarm-node0にてサーバーモードで動かす設定
SSHでログインして、作業を行う。
```sh
# 自分自身のVPNのIPを取得
export MY_VPN_IP=$(
  ip addr show vpn_vlan0 \
  | grep -o -e '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' \
  | head -n1
)

# 設定ファイルに書き出す
cat << EOS > /etc/consul.d/config.json
{
  "server": true,
  "bootstrap": true,
  "bind_addr": "$MY_VPN_IP",
  "datacenter": "swarm0",
  "ui_dir": "/var/local/consul/webui",
  "data_dir": "/var/local/consul/data",
  "log_level": "INFO",
  "enable_syslog": true
}
EOS
```
VPNネットワークである`vpn_vlan0`のIPにバインドする。  
設定が終わったら、自動起動設定と起動を行っておく。
```sh
systemctl enable consul
systemctl start consul
```

#### swarm-node1とswarm-localにてクライアントモードで動かす設定
SSHでログインして、作業を行う。
```sh
# 自分自身のvpnのipを取得
export my_vpn_ip=$(
  ip addr show vpn_vlan0 \
  | grep -o -e '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' \
  | head -n1
)

# 設定ファイルに書き出す
cat << eos > /etc/consul.d/config.json
{
  "server": false,
  "start_join": ["192.168.30.2"],
  "bind_addr": "$MY_VPN_IP",
  "datacenter": "swarm0",
  "ui_dir": "/var/local/consul/webui",
  "data_dir": "/var/local/consul/data",
  "log_level": "INFO",
  "enable_syslog": true
}
EOS
```
joinするIPは固定で割り当てたswarm-node0のものを指定。  
設定が終わったら、自動起動設定と起動を行っておく。
```sh
systemctl enable consul
systemctl start consul
```

#### メンバー確認
各ノードのConsulが連携できているかを確認する。

```sh
$ consul members

Node     Address            Status  Type    Build  Protocol  DC
******  192.168.30.2:8301   alive   server  0.6.1  2         swarm0
******  192.168.30.10:8301   alive   client  0.6.1  2         swarm0
******  192.168.30.11:8301   alive   client  0.6.1  2         swarm0
```

WebUIで確認する場合、ローカルPCのOS設定などから、swarm-node0へVPN接続を行えば、ブラウザで閲覧できる。

```sh
open http://192.168.30.2:8500
```



### 各ノードでDockerを動かす

* 全3ノードに対して、SSHでログインして作業を行う。
* リモートからDockerを操作するため、TCPの2375ポートを使う。
* リモートからSwarmマスターを操作するために、TCPの3375ポートを使う。
* VPNネットワークがあるので、TLS認証は使わない。
* ただし、`vpn_vlan0`以外はポートをファイアウォールで閉じておく。

#### インストール
```sh
wget -qO- https://get.docker.com/ | sh
```

#### ファイアウォール設定
```sh
iptables -A INPUT -i eth0 -p tcp -m tcp --dport 2375 -j DROP
iptables -A INPUT -i eth0 -p tcp -m tcp --dport 3375 -j DROP
```
DigitalOceanのノードのみでよい。

#### Dockerデーモン起動時の引数設定
```sh
vi /lib/systemd/system/docker.service

# 変更前
ExecStart=/usr/bin/docker daemon -H fd://
# 変更後
ExecStart=/usr/bin/docker daemon \
  -H=0.0.0.0:2375\
  --cluster-store=consul://localhost:8500 \
  --cluster-advertise=vpn_vlan0:2375 \
  -H fd://
```
変更後は見やすさのため複数行で書いているが、` \ `を消して1行ぶっ続けで記述する。

#### Docker再起動
```sh
service docker restart
```



### 各ノードでSwarmコンテナを動かす
各ノードにSSHでログインして、Swarmコンテナを起動させる。

#### swarm-node0, swarm-local
```sh
# Swarm Manager
docker run -d --name=swarm-agent-master \
  -v=/etc/docker:/etc/docker --net=host --restart=always \
  swarm manage -H=0.0.0.0:3375 --replication \
    --strategy=spread --advertise=192.168.30.2:3375 consul://localhost:8500

# Swarm Agent
docker run -d --name=swarm-agent --net=host --restart=always \
  swarm join --advertise=192.168.30.2:2375 consul://localhost:8500
```
Swarm Managerについては、双方レプリケーションするために`--replication`引数をつける。

#### swarm-node1
```sh
# Swarm Agent
docker run -d --name=swarm-agent --net=host --restart=always \
  swarm join --advertise=192.168.30.x:2375 consul://localhost:8500
```
`192.168.30.x`のところには、swarm-node1がVPNのDHCPに割り当てられたのIPを入れる。

#### swarm-local
```sh
# Swarm Manager
docker run -d --name=swarm-agent-master \
  -v=/etc/docker:/etc/docker --net=host --restart=always \
  swarm manage -H=0.0.0.0:3375 --replication \
    --strategy=spread --advertise=192.168.30.y:3375 consul://localhost:8500

# Swarm Agent
docker run -d --name=swarm-agent --net=host --restart=always \
  swarm join --advertise=192.168.30.y:2375 consul://localhost:8500
```
`192.168.30.y`のところには、swarm-localがVPNのDHCPに割り当てられたIPを入れる。



### 動作確認

#### ローカルPCのOS設定にて、VPN接続を行う
Macであれば、[SoftEther VPNのドキュメント](http://ja.softether.org/4-docs/2-howto/L2TP_IPsec_Setup_Guide/5)を参考にして、設定を行う。入力値に関しては、この記事の通りにやった場合は以下のようになる。

* サーバーアドレス: (swarm-node0のグローバルIP)
* ユーザーID: user
* パスワード: something
* 共有シークレット： sharedkey

#### ローカルPCから、Swarmマスターに接続してみる
ターミナルなどから以下のコマンドを入力して、Swarmクラスタの接続状況を確認してみる。

```sh
$ docker -H=192.168.30.2:3375 info

Containers: 4
Images: 4
Role: primary
Strategy: spread
Filters: health, port, dependency, affinity, constraint
Nodes: 3
 swarm-local: 192.168.30.11:2375
  └ Status: Healthy
  └ Containers: 1
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 4.053 GiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.2.0-25-generic, operatingsystem=Ubuntu 15.10, storagedriver=aufs
 swarm-node0: 192.168.30.2:2375
  └ Status: Healthy
  └ Containers: 2
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 513.4 MiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.2.0-16-generic, operatingsystem=Ubuntu 15.10, storagedriver=aufs
 swarm-node1: 192.168.30.10:2375
  └ Status: Healthy
  └ Containers: 1
  └ Reserved CPUs: 0 / 1
  └ Reserved Memory: 0 B / 513.4 MiB
  └ Labels: executiondriver=native-0.2, kernelversion=4.2.0-16-generic, operatingsystem=Ubuntu 15.10, storagedriver=aufs
CPUs: 3
Total Memory: 5.055 GiB
Name: swarm-node0
```

ノードが３つ接続されていれば、クラウドとローカルを跨いだSwarmクラスタの構築に成功している状態になる。

ちなみに、`-H=192.168.30.2:3375`の部分は、環境変数`DOCKER_HOST`に`192.168.30.2:3375`と設定しておけば省略できる。


#### 各ノードにコンテナを置いてみる

##### オーバーレイネットワークの作成
```sh
export DOCKER_HOST="192.168.30.2:3375"
docker network create testnet
```
Swarmマスターへの接続であれば、デフォルトでドライバが`overlay`に設定される。

##### docker-compose.yml
```ruby
nginx:
  image: nginx
  net: testnet
  ports:
    - "8080:80"
```
portsを設定しておけば、コンフリクトを防ぐため、コンテナ配置が自然とバラける。

##### docker-compose up & scale
```sh
docker-compose up -d
docker-compose scale nginx=3
```

##### コンテナ配置確認
```sh
$ docker ps --format "{{.Names}}"

swarm-node0/****_nginx_3
swarm-node1/****_nginx_2
swarm-local/****_nginx_1
```
ちゃんとすべてのホストにコンテナが配置できることを確認。`http://192.168.30.x:8080/`各々をブラウザで打ちこめば、nginxのデフォルトページが表示されるはず。

あとは、コンテナの中に`docker exec`で入って、`/etc/hosts`の中を見れば、他のコンテナのIPが書いてあるはずなので、pingを打ってみたりで、オーバーレイネットワークの疎通を確認できる。

