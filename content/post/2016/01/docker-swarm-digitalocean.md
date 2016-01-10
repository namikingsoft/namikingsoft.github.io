---
Categories:
  - Docker Swarm
Tags:
  - DigitalOcean
  - Docker
  - Swarm
date: 2016-01-10T18:00:23+09:00
title: DigitalOceanでマルチホストなDockerSwarmクラスタを構築するときのポイント
---

Docker公式の[Get started with multi-host networking](https://docs.docker.com/engine/userguide/networking/get-started-overlay/)を参考に、DigitalOceanでSwarmクラスタを構築してみたが、いくつか工夫が必要なポイントがあったので、まとめておく。

![Docker Swarm + DigitalOcean](/images/post/2016/01/docker-swarm-digitalocean/logos.png)

### 事前準備

#### 必要なソフトウェアのインストール

作業で使うPC(またはホスト)に以下のDocker関連のソフトウェアをインストールしておく。Dockerのオーバーレイネットワーク機能を使うので、それを利用できるバージョンを入れる。

* docker (1.9以上)
* docker-compose (1.5以上)
* docker-machine


#### DigitalOceanの登録とアクセストークンの取得

登録後、管理画面からdocker-machineとの連携に必要なアクセストークンを発行できる。

https://www.digitalocean.com/



### 気をつけたいポイント４つ

#### 01. ホストOSはKernel3.16以上のものを使う

例えば、ホストOSにUbuntu14.04を選んでいると、オーバーレイ・ネットワーク上にのコンテナを立ち上げる時にエラーが出る。

```bash
$ docker-compose up -d -x-networking

Creating network "xxx" with driver "overlay"
Creating yyy
ERROR: Cannot start container (container_id):
  subnet sandbox join failed for "10.0.0.0/24":
  vxlan interface creation failed for
  subnet "10.0.0.0/24": failed in prefunc:
  failed to set namespace on link "vxlanf9ac2ad": invalid argument
```

[Get started with multi-host networking](https://docs.docker.com/engine/userguide/networking/get-started-overlay/)によると、「A host with a 3.16 kernel version or higher.」とのこと。DigitalOceanのUbuntu14.04はカーネルが古いようなので、14.10とか15.04以上を使う必要がある。


#### 02. cluster-advertiseはeth0にするか、PrivateNetworkを有効にする

[Get started with multi-host networking](https://docs.docker.com/engine/userguide/networking/get-started-overlay/)のサンプルをそのまま使うと、`docker-machine create`時に概ね次のようなエラーに遭遇する。

```
$ docker-machine create \
  ...
  --engine-opt "cluster-advertise=eth1:2376" \
  ...

Error creating machine: Error running provisioning:
Unable to verify the Docker daemon is listening: Maximum number of retries (10) exceeded
```

現状、DigitalOceanの`eth1`はプライベートネットワークのインタフェースで、デフォルト設定では、プライベートネットワークにIPが割り当てられない。

なので、公開ネットワークの`eth0`を使うか、`docker-machine create`時に、全てのノードに`--digitalocean-private-networking`をつけて、プライベートネットワークを有効にする。

```sh
docker-machine create
  ...
  --engine-opt "cluster-advertise=eth0:2376" \
  ...
```
```sh
docker-machine create
  ...
  --engine-opt "cluster-advertise=eth1:2376" \
  --digitalocean-private-networking \
  ...
```


#### 03. ConsulはSwarmクラスタ上に置いて節約する

[公式ドキュメント](https://docs.docker.com/engine/userguide/networking/get-started-overlay/)のサンプルでは、Consulキーストアで専用のホストを用意しているが、安いとはいえ、DigitalOceanでConsulキーストア専用にもつのは守銭奴らしからぬので、Swarmマスターやノードホストに含めてしまおう。

Swarmクラスタのノードを作成するときに、ConsulのURLを指定する場所があるが、作成時にはConsulキーストアが存在しなくても、Swarmが後々定期的にキーストアを更新してくれるようなので、割りと気にせずにノード構築後にConsulを導入できる。

ただ、サンプルのように、ConsulをDockerコンテナで導入してしまうと、`docker ps`時に、いつもリストに出てきてしまうので、気になる方はDocker上ではなく、ホストに直接インストールしてしまったほうが良い。(バイナリファイル１つだし)

あと、Consulらしく全ノードに設置して、ヘルスチェックなどが出来ると良さそう。

![Docker Swarm + DigitalOcean](/images/post/2016/01/docker-swarm-digitalocean/structure.svg)


#### 04. Consulはプライベートネットワークに置く

[公式ドキュメント](https://docs.docker.com/engine/userguide/networking/get-started-overlay/)の感覚で、DigitalOceanにConsulキーストアを導入すると、グローバルにWebUIが公開されてしまい、精神的によろしくない。

DigitalOceanには、一応プライベートネットワーク機能が用意されていて、管理画面やdocker-machineの引数から有効にできる。Consulはプライベートネットワーク側(eth1)のIPをバインドするとよい。

プライベートネットワークにConsulを置くと、WebUIなどはグローバルIPから確認できなくなる。ブラウザからWebUIを確認したくなった場合は、SSHトンネルを利用して、8500ポートをフォワーディングしてやると楽。

```sh
ssh root@(マシンIP) \
  -i ~/.docker/machine/machines/(マシンID)/id_rsa \
  -L8500:localhost:8500

# ブラウザから開く
open http://localhost:8500
```

> **注意**  
> プライベートネットワークといっても、
> リージョンごとのネットワークのようなので、
> あまり過信しないほうがよいみたい。
>
> 使う前に知りたかったDigitalOceanまとめ
> http://pocketstudio.jp/log3/2015/04/13/digitalocean_introduction/


### 具体的な実行手順

自動化しやすいように、上のポイント４つを踏まえたシェルの実行手順を以下にまとめる。

```sh
# マスター作成
docker-machine create \
  --driver digitalocean \
  --digitalocean-access-token ${DIGITALOCEAN_TOKEN} \
  --digitalocean-image "ubuntu-15-10-x64" \
  --digitalocean-region "sgp1" \
  --digitalocean-size "512mb" \
  --digitalocean-private-networking \
  --swarm --swarm-master \
  --swarm-discovery \
    "consul://localhost:8500" \
  --engine-opt \
    "cluster-store=consul://localhost:8500" \
  --engine-opt "cluster-advertise=eth1:2376" \
  swarm-master

# マスターにConsulを設置
docker-machine ssh swarm-master "
  apt-get install -y at zip &&\
  cd /tmp &&\
  curl -LO https://releases.hashicorp.com/consul/0.6.1/consul_0.6.1_linux_amd64.zip &&\
  unzip consul_0.6.1_linux_amd64.zip &&\
  mv consul /usr/local/bin &&\
  curl -LO https://releases.hashicorp.com/consul/0.6.1/consul_0.6.1_web_ui.zip &&\
  unzip consul_0.6.1_web_ui.zip -d consul-webui &&\
  echo \"
    consul agent \
      -server -bootstrap-expect=1 \
      -node=consul00 \
      -data-dir=/tmp/consul \
      --ui-dir=/tmp/consul-webui \
      -bind=\$(
        ip addr show eth1 \
        | grep -o -e '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' \
        | head -n1
      ) \
    >> /var/log/consul.log
  \" | at now
"

# マスターのプライベートIPを取得
MASTER_PRIVATE_IP=$(
  docker-machine ssh $MASTER_NODE_NAME "
    ip addr show eth1 \
    | grep -o -e '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' \
    | head -n1
  "
)

# ノード作成
docker-machine create \
  --driver digitalocean \
  --digitalocean-access-token ${DIGITALOCEAN_TOKEN} \
  --digitalocean-image "ubuntu-15-10-x64" \
  --digitalocean-region "sgp1" \
  --digitalocean-size "512mb" \
  --digitalocean-private-networking \
  --swarm \
  --swarm-discovery \
    "consul://localhost:8500" \
  --engine-opt \
    "cluster-store=consul://localhost:8500" \
  --engine-opt "cluster-advertise=eth1:2376" \
  swarm-node01

# ノードにConsulを設置
docker-machine ssh swarm-node01 "
  apt-get install -y at zip &&\
  cd /tmp &&\
  curl -LO https://releases.hashicorp.com/consul/0.6.1/consul_0.6.1_linux_amd64.zip &&\
  unzip consul_0.6.1_linux_amd64.zip &&\
  mv consul /usr/local/bin &&\
  echo \"
    consul agent \
      -join=$MASTER_PRIVATE_IP \
      -node=consul01 \
      -data-dir=/tmp/consul \
      -bind=\$(
        ip addr show eth1 \
        | grep -o -e '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' \
        | head -n1
      ) \
    >> /var/log/consul.log
  \" | at now
"
```

#### 注記いくつか

* シェル中の`${DIGITALOCEAN_TOKEN}`はDigitalOceanの管理画面から取得したアクセストークンに置き換える。
* Consul起動に`at now`コマンドを使っているのは、`nohup`や`&`を使っても、Consulがフォアグラウンドで走ってしまい、バッチ処理が途中で止まってしまうため。`docker-machine ssh`の仕様の問題？
* Consul実行時にbindに指定しているのは、自身のプライベートIP。
* 途中で、マスターのプライベートIPを取得しているのは、各ノードに設置したConsulクライアントをサーバーにJOINさせるため。
