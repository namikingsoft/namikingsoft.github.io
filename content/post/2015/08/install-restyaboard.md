---
Categories:
  - かんばん式プロジェクト管理
Tags:
  - Restyaboard
  - OSS
  - Vagrant
  - Itamae
date: 2015-08-27T08:16:13+09:00
title: かんばん式プロジェクト管理OSSのRestyaboardをインストールしてみる
---

![Resyaboard ScreenShot](/images/post/2015/08/install-restyaboard/index.jpg)

`Restyaboard`はプロジェクトをかんばん形式で管理できるオープンソースソフトウェア。
GitHubを見ると今年の中旬頃に`Initial commit`ということで、表に出たのは最近なんだろうか。

`Pivotal Tracker`, `Trello`あたりは仕事でも使いたいなーとは思うのですが、  
クラウドっすか・・(^_^;) みたいな現場もあるので、
クローズドな環境に導入できるかんばんツールはかなりありがたい。

> Restyaboard | Trello like kanban board. Based on Restya platform.  
> http://restya.com/board/

AMIも提供しているとのことですが、
どの環境でも導入できるように構築手順を確立しておきたい。
んが、公式ドキュメントにインストール手順が記載されていなかったので、試行錯誤して何とか動くところまで持ち込んでみた。


インストール手順
------------------------------

必要なコンポーネントがそこそこ多く、インストール手順も面倒なため、  
`Dockerfile`を作っておいた。追記：2015/08/31

> GitHub: Docker Restyaboard  
> https://github.com/namikingsoft/docker-restyaboard


### 動作確認環境

* インフラ
  * AWS EC2 t2.micro
* OS/ディストリビューション
  * Amazon Linux
* インストールするソフトウェア
  * Restyaboard Ver.0.1.1
* デプロイパス
  * /var/www/board
* 必要なミドルウェア
  * PostgreSQL 9.x
  * PHP 5.x
  * nginx
  * node.js (ビルドに必要)
  * Elasticsearch (任意？)


### node.js

サーバー動作には使わないっぽいが、
`less`や`jst`のビルドに必要。

#### インストール

```bash
$ sudo yum install -y nodejs npm
$ sudo npm install -g grunt-cli
```


### Restyaboard

#### ダウンロード

```bash
$ cd /var/www
$ sudo git clone https://github.com/RestyaPlatform/board.git
```

#### パーミッション設定

アップロードした画像やファイルを保存するディレクトリに書き込み権限を付加。

```bash
$ sudo chmod -R o+w /var/www/board/client/img
$ sudo chmod -R o+w /var/www/board/media
```

#### ビルド

```bash
$ cd /var/www/board
$ sudo npm install
$ sudo grunt build
```

#### R設定

PostgreSQL関連の認証情報が初期化されたので、環境に応じて設定を変更する。

```bash
$ sudo vi /var/www/board/server/php/R/config.inc.php
```

ここでは以下の項目を書き換えた。

```php
define('R_DB_USER', 'restya');
define('R_DB_PASSWORD', 'password');
```


### PostgreSQL

#### インストール＆サービス起動

```bash
$ sudo yum install -y postgresql94-server

$ sudo chkconfig postgresql94 on
$ sudo service postgresql94 initdb
$ sudo service postgresql94 start
```

#### DB設定＆ユーザー作成

```bash
$ sudo su - postgres
$ psql -U postgres -c \
  "CREATE USER restya WITH ENCRYPTED PASSWORD 'password'"
$ psql -U postgres -c \
  "CREATE DATABASE restyaboard OWNER restya ENCODING 'UTF8'"
$ exit
```

#### 認証設定

```bash
$ sudo vi /var/lib/pgsql94/data/pg_hba.conf
```
既存のものはコメントアウトして、以下を追記する。
```
local all postgres peer
local all all md5
host all all 127.0.0.1/32 md5
host all all ::1/128 md5
```
`host`の設定をしないと、PHPで接続エラーが出るので注意。

#### 初期データ登録

```bash
$ sudo su - postgres
$ psql -U postgres -d restyaboard -f \
  /var/www/board/sql/restyaboard_with_empty_data.sql
$ exit
```


### nginx

WebAPI用のサーバー。

#### インストール

```bash
$ sudo yum install -y nginx
```

#### conf設定

設定例はRestyaboardのデプロイパスに格納されているので、
そこからコピーして、環境に応じて書き換える。

```bash
$ sudo cp /var/www/board/restyaboard.conf /etc/nginx/conf.d/
$ sudo vi /etc/nginx/conf.d/restyaboard.conf
```

一括置換 `/usr/share/nginx/html` → `/var/www/board`

#### サービス起動

```bash
$ sudo chkconfig nginx on
$ sudo service nginx start
```


### PHP

RestyaboardのPHPソースに`PHP version 5`とあるので、PHP5.6で動作させてみる。
以下のパッケージをいれれば、ひと通り動作するっぽい。

#### インストール

```bash
$ sudo yum install -y \
    php56 php56-fpm php56-pgsql php56-mbstring php56-gd php56-pecl-imagick
```

`Amazon Linux`であれば、標準リポジトリにPHP5.6が入っているみたい。
別ディストリビューションであれば、`remi`リポジトリなどを追加してから、
インストールする。

#### php-fpmの設定

デフォルト設定がApache用になっているので、nginx用に書き換える。

```bash
$ sudo vi /etc/php-fpm.d/www.conf
```

* `user = apache` →  `user = nginx`
* `group = apache` →  `group = nginx`

#### サービス起動

```bash
$ sudo chkconfig php-fpm on
$ sudo service php-fpm start
```


### ElasticSearch

無くても、ある程度動くっぽいが一応。  
URLやIndexの設定は、インストール後のRestyaboard管理画面からできる。

#### リポジトリ追加

```bash
$ sudo vi /etc/yum.repos.d/elasticsearch.repo
```

```ini
[elasticsearch-1.0]
name=Elasticsearch repository for 1.0.x packages
baseurl=http://packages.elasticsearch.org/elasticsearch/1.0/centos
gpgcheck=1
gpgkey=http://packages.elasticsearch.org/GPG-KEY-elasticsearch
enabled=0
```

#### インストール＆サービス起動

```bash
$ sudo yum install -y --enablerepo='elasticsearch-1.0' elasticsearch

$ sudo chkconfig elasticsearch on
$ sudo service elasticsearch start
```

#### Crontab設定

インデックス更新のために、Crontabを設定する。  
5分毎に更新する場合は、以下のようにする。

```bash
$ crontab -e
```

```bash
*/5 * * * * php /var/www/board/server/php/R/shell/cron.php
```

### ファイアウォール設定など

AWSならセキュリティグループから、
その他Linuxなら`iptables`,`firewalld`などから、
`80`ポートを外向けに開放しておく。


動作確認
------------------------------

#### URL

```
http://(サーバーIP)/
```

ログインフォームが出てくれば、大方OK。

#### ログイン情報

```
管理者権限
Username: admin
Password: restya

ユーザー権限
Username: user
Password: restya
```

#### つまづいた点

* ログインフォームが表示されない
  * PostgreSQLとのコネクションに失敗していた。
  * `pg_hba.conf`でhostを設定することで解決
* ログイン後のフッターメニューが表示されない
  * PostgreSQLとのコネクションに失敗していた。
  * `pg_hba.conf`でhostを設定することで解決
* アップロードした画像が表示されない。
  * パーミッションの設定が正しくない。
  * PHPパッケージが足りてなかった、`php-gd`,`php-pecl-imagick`
* ボード編集中に、APIサーバーエラー(500)が頻発する
  * PHPパッケージが足りてなかった、`mstring`

PostgreSQLやPHPパッケージの設定がうまく行えていないと、
上の様な不具合が出たりする。


まとめ
------------------------------

構築手順や必要なパッケージが全て公開されていないため、
インストールはほぼデバッグ作業でしたが、なんとかうまく動かせるまでに至った。

`Trello`などと比べるとUIはまだ洗練中という印象ですが、
基本的な機能はほぼ抑えているので、隙を見て使っていこうかな。


#### 追記： 2015/08/28
`LibreBoard`というのもあるらしい。こちらもTrelloクローンのOSS。  
Dockerfileも用意されてたので、インストールが楽すぎて泣く。

> GitHub: LibreBoard  
> https://github.com/libreboard/libreboard

ちょっと触った感じだと、かなり絞ったシンプルなTrelloという感じ。
機能面では、`Restyaboard`の方が豊富な印象だが、
その分、UIもシンプルでとっつきやすい。

そのうち、細かい機能比較とかもまとめておきたい。



