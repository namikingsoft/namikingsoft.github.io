---
Categories:
  - Docker Swarm
Tags:
  - Docker
  - Swarm
  - Spark
date: 2016-01-12T23:30:23+09:00
title: Docker SwarmでApache Sparkクラスタを構築してみる
---

[前回の記事](/post/2016/01/docker-swarm-digitalocean/)でSwarmクラスタを構築したので、Apache Sparkのクラスタを載せてみる。

本来ならオンプレでクラスタを組んだり、AmazonのEMRを使うのが一般的かもだが、安めのクラウドでもできないかなーという試み。

まずはシンプルに、Standaloneモードから動かしてみたい。

### 事前準備

#### マルチホスト同士の通信が可能なSwarmクラスタを構築しておく

Sparkのクラスタ同士は、一方通行な通信ではなく、割りと親密な双方向通信をするため、オーバーレイ・ネットワーク上に構築しないとうまく動作しない。

オーバーレイ・ネットワーク構築するには、Consul, etcd, Zookeeperのようなキーストアを自身で導入する必要があるので、
[DigitalOceanでマルチホストなDockerSwarmクラスタを構築](/post/2016/01/docker-swarm-digitalocean/)を参考に、以下の様なSwarmクラスタを構築しておいた。

![Swarm Structure](/images/post/2016/01/docker-swarm-spark/structure-swarm.svg)



### Sparkクラスタをコンテナで構築する

docker-composeを用いて、各ノードにSparkクラスタを構築する。


![Spark Containers](/images/post/2016/01/docker-swarm-spark/spark-containers.svg)


#### Apache SparkのDockerイメージ

Standaloneモードで動くシンプルなものが使いたかったので、SparkのDockerイメージは自前で用意したものを使った。

> namikingsoft/docker-spark  
> https://github.com/namikingsoft/docker-spark

masterなら`bin/start-master.sh`を実行し、workerなら`bin/start-slave.sh ${MASTER_HOSTNAME}:7077`を実行するだけのシンプルなもの。

#### docker-compose.yml

```ruby
master:
  image: namikingsoft/spark
  hostname: master
  container_name: master
  environment:
    - constraint:node==/node0/
  privileged: true
  command: master

worker:
  image: namikingsoft/spark
  environment:
    - MASTER_HOSTNAME=master
    - constraint:node!=/node0/
    - affinity:container!=/worker/
  privileged: true
  command: worker
```

`environment`からの`constraint`や`affinity`の指定によってコンテナの配置をコントロールできる。コンテナの数をスケールするときもこのルールに沿って配置される。  
[>> 指定方法の詳細](https://docs.docker.com/swarm/scheduler/filter/)

イメージ各コンテナはDockerのオーバーレイネットワークで繋がるので、
ポートも特に指定しなくてもよい。WebUIなどは後ほど、Socksプロキシ経由で確認する。


#### Swarm Masterの環境変数を設定

```sh
eval "$(docker-machine env --swarm swarm-node0)"
```


#### docker-compose up

```sh
docker-compose --x-networking up -d
```

`--x-networking`を引数で指定すれば、各コンテナがDockerのオーバーレイ・ネットワークで繋がる。`--x-network-driver overlay`を省略しているが、デフォルトで指定されるみたい。


`docker-compose up`直後の状態では、ワーカーコンテナが１つしか立ち上がらないので、以下の様な感じになっている。

![Spark Containers Progress](/images/post/2016/01/docker-swarm-spark/spark-containers-progress.svg)

#### ワーカーをスケールしてみる

docker-composeのscaleコマンドでワーカーノードを指定数分スケールすることができる。

```sh
docker-compose scale worker=2
```

#### コンテナ配置の確認

```sh
docker ps --format "{{.Names}}"
```
```sh
swarm-node0/master
swarm-node1/dockerspark_worker_1
swarm-node2/dockerspark_worker_2
```

各ノードにコンテナが配置されたのがわかる。


> **ちなみに、MasterとWorkerを一緒のノードで動かしたら**  
> spark-shell起動時に`Cannot allocate memory`的なエラーを吐いた。
> チューニング次第かもだが、DigitalOcean 2GBだとリソース的には厳しそう。


### Sparkシェルを動かしてみる

仮にSparkマスターコンテナをドライバーとして、動かしてみる。
(ワーカーでも動作可能)

```sh
docker-exec -it master bash
spark-shell --master spark://master:7077
```
```scala
scala> sc.parallelize(1 to 10000).fold(0)(_+_)
res0: Int = 50005000
```


### Spark UIを確認

SparkのWebUIから、ワーカーが接続されているか確認したいが、docker-compose.ymlではポートを開けていない。(本来閉じたネットワークで動かすので、ポートを開放するのはあまりよろしくない)

なので、新たにSSHdコンテナを設置して、Socksプロキシ経由でWebUIを確認する。

![Sparkマスター WebUI](/images/post/2016/01/docker-swarm-spark/spark-sshsocks.svg)


#### SSHdコンテナを追加

先ほどのdocker-compose.ymlに追加する。
```ruby
master:
  image: namikingsoft/spark
  hostname: master
  container_name: master
  environment:
    - constraint:node==/node0/
  privileged: true
  command: master

worker:
  image: namikingsoft/spark
  hostname: woker
  environment:
    - constraint:node!=/node0/
    - affinity:container!=/worker/
  privileged: true
  command: worker

# SSHdコンテナを追加
sshd:
  image: fedora/ssh
  ports:
    - "2222:22"
  environment:
    SSH_USERNAME: user
    SSH_USERPASS: something
```

以下のコマンドで、SSHdコンテナが起動する。
```sh
docker-compose --x-networking up -d
```

#### ローカルPCでSocksプロキシを起動

swarm-masterのIPを確認。
```sh
docker-machine ls
```

Socksプロキシの起動。
```sh
ssh user@(swarm-masterのIP) -p2222 -D1080 -fN
Password: something
```
Socksプロキシを止めるときは`Ctrl-c`を押下。


#### ローカルPCにてSocksプロキシを設定

ローカルPCのSocksプロキシ設定を`localhost:1080`に設定する。
SSHのSocks周りについては以下のページが参考になった。

[ssh経由のSOCKSプロキシを通じてMac上のGoogle Chromeでブラウジング](http://blog.wktk.co.jp/ja/entry/2014/03/11/ssh-socks-proxy-mac-chrome)  
[ssh -D と tsocks -  京大マイコンクラブ (KMC)](https://www.kmc.gr.jp/advent-calendar/ssh/2013/12/14/tsocks.html)


#### ブラウザで確認

```sh
open http://(swarm-masterのIP):8080
```
![Sparkマスター WebUI](/images/post/2016/01/docker-swarm-spark/spark-master-ui.png)

先ほど、スケールした2つのワーカーコンテナがマスターに接続されているのがわかる。
IPや名前解決はSSH接続先のものを参照してくれて便利。(OSX10.9+Chromeで確認)

![Sparkワーカー WebUI](/images/post/2016/01/docker-swarm-spark/spark-worker-ui.png)



