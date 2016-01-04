---
Categories:
  - フロントエンド関連
Tags:
  - webpack
  - webpack-dev-server
date: 2015-09-12T08:30:23+09:00
draft: true
title: webpack-dev-serverでフロントエンドの動作確認をする
---

Expressで組むかー(白目)と考えていたところに、`webpack-dev-server`に出会う。
`redux`周りのGitHubを見てた時に、最近、`webpack`という〜管理を使い始めて、
概要。

> WEBPACK DEV SERVER  
> http://webpack.github.io/docs/webpack-dev-server.html


### 動かしてみる

#### inlineモード

#### hotモード

#### iframeモード

ファイルを更新した場合などに、上部のステータスバーに状況が出てくる。
```
http://localhost:8081/webpack-dev-server/
```



### ハマったところ

# resolve root で書いたら、webpack-dev-serverのhotが効かない

# stylus はresolveのrootが効かない？

エラーが出る

#### コンソールにエラー

```
[HMR] Hot Module Replacement is disabled.
```

#### babel-loaderを使おうと思ったら、コンソールにエラー

```
TypeError: Cannot read property 'WebSocket' of undefined
```

mapファイルが出ない。

説明書はよく読もう。

タイトル
------------------------------

### インストール手順

公式ドキュメントに対応OSごとのインストール方法がまとめてあった。

