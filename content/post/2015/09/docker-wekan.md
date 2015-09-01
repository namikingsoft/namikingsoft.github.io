---
Categories:
  - かんばん式管理ツール
Tags:
  - Wekan
  - LibreBoard
  - Docker
  - OSS
date: 2015-09-01T09:30:23+09:00
title: Wekan on Dockerでお手軽かんばん式プロジェクト管理
---

かんばん式管理ツール`Wekan`は`Trello`クローンの一つ。  
ちょっと前まで、`LibreBoard`という名前の`Trello`クローンでしたが、
最近、`Wekan`という名前に変わったようです。  
必要最低限の機能がコンパクトにまとまっていて非常に扱いやすい。

少し触ってみたところ、機能的には`LibreBoard`のままで、
以前より見栄えにオリジナリティが増したように感じます。

![Wekan ScreenShot](/images/post/2015/09/docker-wekan/wekan01.jpg)


### Dockerを利用した導入手順

公式のGitHubに置いてあったDockerfileを参考にさせていただく。

> GitHub: wekan/wekan  
> https://github.com/wekan/wekan

#### 00. 事前準備

`Docker`と`docker-compose`をインストールしておく。

#### 01. docker-compose.yml 設置

以下の内容の`docker-compose.yml`を設置する。  
`ROOT_URL`辺りを各々の環境に合わせて書き換える。

```
data:
  image: busybox
  volumes:
    - /data/db

mongo:
  image: mongo
  volumes_from:
    - data
  restart: always

wekan:
  image: mquandalle/wekan
  environment:
    MONGO_URL: mongodb://db
    ROOT_URL: http://example.com
  links:
    - mongo:db
  ports:
    - "8080:80"
  restart: always
```

#### 02. Docker起動

先ほどの`docker-compose.yml`があるディレクトリ内で、以下のコマンドを入力。
```
docker-compose up -d
```

#### 03. 動作確認
画面内の「登録する」から、ユーザーを登録を行う。
```
http://(SERVER_IP):8080/
```
