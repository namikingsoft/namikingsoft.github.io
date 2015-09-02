---
Categories:
  - Docker関連
Tags:
  - Docker
  - docker-compose
date: 2015-09-02T08:30:23+09:00
title: docker-composeのインストールとバージョン差異エラー回避方法
---

`docker-compose`はDockerコンテナの構成管理ツール。  
昔は`fig`という名前のツールだったが、Dockerと統合して名前を変更したとのこと。

データボリューム, DB, バックエンド、フロントエンドなど、
サービスの稼働に複数コンテナが必要な場合、立ち上げが非常に簡単になる。

インストール自体はシンプルだが、
Dockerのバージョンによっては実行時にエラーが出てしまうようなので、
エラー回避方法もまとめておく。

> Overview of Docker Compose  
> https://docs.docker.com/compose/


### インストール手順

公式ドキュメントに対応OSごとのインストール方法がまとめてあった。

> Docker Compose: Supported installation  
> https://docs.docker.com/installation/

OS共通の方法で一番簡単なのが、`pip`でインストールする方法。

```bash
pip install -U docker-compose
```

`pip`がない場合は、`easy_install`でインストールできる。

```bash
easy_install pip
```



### バージョン差異エラー回避方法

`docker-compose up`などの実行時に、以下の様なエラーが表示されることがある。

```
client and server don't have same version (client : 1.19, server: 1.18)
```

#### 原因

このエラーは、インストールされている`Dockerサーバー`のバージョンと、
`docker-composeクライアント(API)`のバージョンに互換性がない時に表示されるらしい。

#### 回避方法

`COMPOSE_API_VERSION`環境変数にサーバーのバージョンを設定すれば、
`docker-compose`の方で、サーバーのバージョンに合わせて通信してくれるとのこと。
`auto`を設定すれば、自動で調整してくれるみたい。便利。


以下のコマンドを入力するか、`/etc/profile`とか`~/.bash_profile`あたりに追記しておく。

```
export COMPOSE_API_VERSION=auto
```

`/etc/environment`に追記する場合は以下のようにする。

```
COMPOSE_API_VERSION=auto
```

### docker-composeの利用例

当ブログの以下の記事で、具体的な使用例を紹介しているので、参照されたい。

* [TAIGA on Dockerで本格アジャイル開発管理](/post/2015/09/docker-taiga/)
* [Wekan on Dockerでお手軽かんばん式プロジェクト管理](/post/2015/09/docker-wekan/)
* [Restyaboard on Dockerで多機能かんばん式プロジェクト管理](/post/2015/09/docker-restyaboard/)


