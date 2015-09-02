---
Categories:
  - かんばん式管理ツール
Tags:
  - Restyaboard
  - Docker
  - OSS
date: 2015-09-01T08:30:23+09:00
title: Restyaboard on Dockerで多機能かんばん式プロジェクト管理
---

`Restyaboard`は`Trello`クローンの一つですが、UIは前衛的で多機能。  
Trelloだと、有料ユーザーしかできないことが、普通にできたりする。

![Restyaboard ScreenShot](/images/post/2015/09/docker-restyaboard/restyaboard01.jpg)

> Restyaboard  
> http://restya.com/board/


### Dockerを利用した導入手順

公式ページに必要なミドルウェアは書いてあるが、
導入手順が書かれていないっぽい。
ちみちみデバッグしながら、構築した手順を`Dockerfile`にまとめておいた。

> GitHub: namikingsoft/docker-restyaboard  
> https://github.com/namikingsoft/docker-restyaboard


#### 00. 事前準備

`Docker`と`docker-compose`[^1]をインストールしておく。

[^1]: 参考： [docker-composeのインストールとバージョン差異エラー回避方法](/post/2015/09/install-docker-compose/)

#### 01. Dockerイメージビルドとコンテナ起動

以下のコマンドで、Docker環境を構築できる。

```bash
git clone https://github.com/namikingsoft/docker-restyaboard.git
cd docker-restyaboard

docker-compose up -d
```

`docker-compose up -d`でイメージのビルドとコンテナ起動を全て自動でやってくれる。
イメージビルドにそこそこ時間が掛かるので注意。

#### 02. 動作確認

```
http://(ServerIP):1234

管理ユーザー
Username: admin
Password: restya

一般ユーザー
Username: user
Password: restya
```
