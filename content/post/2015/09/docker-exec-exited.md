---
Categories:
  - Docker関連
Tags:
  - docker
  - インフラ
date: 2015-09-29T08:00:00+09:00
title: Dockerイメージのビルド中にExitedしたコンテナに入る方法
---

長めのansible-playbookをRUNしてる途中でエラーが出た時に役立ったので、まとめておく。



### どういう時に使う？

例えば、`docker build`途中によくわからない理由でエラー落ちした時、
直前状態のコンテナに入ってデバッグしたい事がある。

ビルドに失敗した後、`docker ps -a`すると、
`Exited`したビルド作業用のコンテナが消されずに残っているので、
このコンテナの中にシェルで入れれば、エラーの詳細を調べられる。

> コンテナだけでなく、直近のイメージも残っているが、
> Dockerコマンド単位でコミットされるため、
> 数珠つなぎのRUNとか、ansibleやchefなどのプロビジョニングツールを併用した時に、
> 大幅にロールバックしていることがある。


#### ビルド途中にエラーで落ちるDockerfileの例

```docker
FROM busybox

RUN touch /step1
RUN touch /step2 && errcmd && touch /step3
RUN touch /step4
```

`errcmd`という架空のコマンドで、わざとエラーを起こしてみる。


#### docker build の途中で落ちる

```sh
$ docker build . -t tset

Sending build context to Docker daemon 2.048 kB
Sending build context to Docker daemon
Step 0 : FROM busybox
latest: Pulling from library/busybox
cfa753dfea5e: Pull complete
d7057cb02084: Pull complete
library/busybox:latest: The image you are pulling has been verified. Important: image verification is a tech preview feature and should not be relied on to provide security.
Digest: sha256:16a2a52884c2a9481ed267c2d46483eac7693b813a63132368ab098a71303f8a
Status: Downloaded newer image for busybox:latest
 ---> d7057cb02084
Step 1 : RUN touch /step1
 ---> Running in f1ca76c9072d
 ---> ef649ff08895
Removing intermediate container f1ca76c9072d
Step 2 : RUN touch /step2 && errcmd && touch /step3
 ---> Running in d117aa39bacd
/bin/sh: errcmd: not found
The command '/bin/sh -c touch /step2 && errcmd && touch /step3' returned a non-zero code: 127
```

途中にある`---> Running in d117aa39bacd`の次で止まっている。

```sh
$ docker ps -q --filter status=exited

d117aa39bacd
```

`d117aa39bacd`コンテナが消されずに残っている。  
これが直近の作業コンテナで`touch /step2`までのコマンドを実行されているはず。


#### Exitedなコンテナには入れない？

生きているコンテナであれば、`docker exec`+シェルでコンテナの中に入れるが、
Exitedしていると、以下の様なエラーが出る。

```sh
$ docker exec -it d117aa39bacd sh

Error response from daemon: Container d117aa39bacd is not running
```



### 解決手順

#### １．Exitedコンテナを一旦コミットして、イメージ化する

死んでいるコンテナをコミットするという機会があまりなかったので、
ちょっと戸惑ったが、以下のコマンドでイメージ化できる。

```sh
$ docker commit -t exited d117aa39bacd
```


#### ２．インタラクティブ+TTYモードで実行する

そのまま`docker run`しても速攻で死ぬので、`-it bash`をつけて実行。

```sh
$ docker run --rm -it exited sh
```

```sh
# ls / | grep step
step1
step2
```

ちょっとまどろっこいが、一応エラーコマンド直前の状態のコンテナに入れた。
同じRUNコマンドの中でエラーが起きても、`touch /step2`までは実行されているようだ。
