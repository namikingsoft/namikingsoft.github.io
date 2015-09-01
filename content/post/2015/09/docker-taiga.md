---
Categories:
  - かんばん式管理ツール
Tags:
  - TAIGA
  - Docker
  - OSS
date: 2015-09-01T10:30:23+09:00
title: TAIGA on Dockerで本格アジャイル開発管理
---

`TAIGA`は、やたらデザインがきれいなアジャイルプロジェクト管理ツール。  
`Trello`クローンという感じはなく、`Redmine`拡張の`Alminium`に似ている。

ストーリーカードの重み付けやタスクボード、バーンダウンチャートなども備えており、
しっかりとアジャイル開発をやりたい場合はおすすめ。

![TAIGA ScreenShot](/images/post/2015/09/docker-taiga/taiga01.png)
![TAIGA ScreenShot](/images/post/2015/09/docker-taiga/taiga02.png)


### Dockerを利用した導入手順

以下の`docker-compose.yml`とイメージを参考/利用させていただきました。

> GitHub: htdvisser/taiga-docker  
> https://github.com/htdvisser/taiga-docker

#### 00. 事前準備

`Docker`と`docker-compose`をインストールしておく。

#### 01. docker-compose.yml 設置

以下の内容の`docker-compose.yml`を設置する。  
`hostname`, `EMAIL_*`辺りは各々の環境に合わせて書き換える。

```
data:
  image: tianon/true
  volumes:
    - /var/lib/postgresql/data
    - /usr/local/taiga/media
    - /usr/local/taiga/static
    - /usr/local/taiga/logs

db:
  image: postgres
  environment:
    POSTGRES_USER: taiga
    POSTGRES_PASSWORD: password
  volumes_from:
    - data
  restart: always

taigaback:
  image: htdvisser/taiga-back:stable
  hostname: example.com
  environment:
    SECRET_KEY: examplesecretkey
    EMAIL_USE_TLS: True
    EMAIL_HOST: smtp.gmail.com
    EMAIL_PORT: 587
    EMAIL_HOST_USER: example@gmail.com
    EMAIL_HOST_PASSWORD: password
  links:
    - db:postgres
  volumes_from:
    - data
  restart: always

taigafront:
  image: htdvisser/taiga-front-dist:stable
  hostname: example.com
  links:
    - taigaback
  volumes_from:
    - data
  ports:
    - 0.0.0.0:80:80
  restart: always
```

#### 02. Docker起動

先ほどの`docker-compose.yml`があるディレクトリ内で、以下のコマンドを入力。
```
docker-compose up -d
```

#### 03. 足りないDBレコードを挿入

Docker起動時に、ある程度初期DBデータの挿入が行われるが、
おそらく`TAIGA`のバージョンアップで、必要なDBデータが増えたのか、
動作確認時にプロジェクトが作成できない[^1]、などの不具合を起こしていたので、
取り急ぎ、こちらのコマンドで入れておく。

```bash
docker exec -it (taigabackコンテナID) \
  python /usr/local/taiga/taiga-back/manage.py \
    loaddata initial_project_templates

docker exec -it (taigabackコンテナID) \
  python /usr/local/taiga/taiga-back/manage.py \
    loaddata initial_project_templates initial_user

docker exec -it (taigabackコンテナID) \
  python /usr/local/taiga/taiga-back/manage.py \
    loaddata initial_project_templates initial_role
```

#### 04. 動作確認

##### 通常画面
画面内の「create your free account here」からユーザー登録を行う。
```
http://(SERVER_IP)/
```

##### 管理画面
DBレコード操作などを行う画面？  
通常運用であれば、使わなくてもよい画面と思われる。
```
http://(SERVER_IP)/admin/
Username: admin
Password: 123123
```


### 導入でつまづいた点

##### 新規ユーザー登録ボタン押下後に、次画面に遷移しない。
* SMTP設定が正しくない。
* Docker起動直後に登録した。(初期DBデータ登録が終わっていない？)

##### プロジェクトの作成途中で次画面に遷移しなくなる。
* 追加DBデータを挿入していない。


[^1]: 参考： https://github.com/taigaio/taiga-scripts/issues/23
