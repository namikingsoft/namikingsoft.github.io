---
Categories:
  - かんばん式管理ツール
Tags:
  - TAIGA
  - Wekan
  - Restyaboard
  - OSS
date: 2015-09-04T08:30:23+09:00
title: オープンソースのかんばん式管理ツールを３つほど試してみた
---

コンプライアンス[^1]を重視する現場で、
アジャイルなプロジェクト管理ツールが現場で必要になったときに、
外部Webサービスな`Trello`や`Pivotal Tracker`を導入しづらいことがある。

そこで、OSSのかんばん式管理ツールをいくつか探して、  
色々試して感じたことをまとめておきます。

[^1]: いまいちピンとこない用語だが、ここでは情報漏洩を気にする企業という意味。内部サーバーだからバッチグーという事ではなく、いかにお固い上席を説得しやすいか。


### 今回試した 'かんばん式' プロジェクト管理ツール

以下に挙げる以外にも、OSSのかんばん式管理ツールは数多く存在するが、
機能面・とっつきやすさ・導入の容易さなどに基いて、３つだけピックアップさせていただいた。

* TAIGA  
https://taiga.io/

* Wekan (旧LibreBoard)  
http://newui.libreboard.com

* Restyaboard  
http://restya.com/board/


#### 個別のサーバーに実行環境を構築したい場合

各々デモ用のURLが用意されているが、OSSなので個別のサーバー環境や`Docker`で試したい場合は、
当ブログに構築手順の記事があるので、参照されたい。

* [TAIGA on Dockerで本格アジャイル開発管理](/post/2015/09/docker-taiga/)
* [Wekan on Dockerでお手軽かんばん式プロジェクト管理](/post/2015/09/docker-wekan/)
* [Restyaboard on Dockerで多機能かんばん式プロジェクト管理](/post/2015/09/docker-restyaboard/)


TAIGA - 本格的なアジャイル開発管理
------------------------------

本格的なアジャイル開発を支援するプロジェクト管理ツール。
他のかんばん管理ツールに比べて、デザイン洗礼されていて、使っていて気持ちいい。

![TAIGA ScreenShot](/images/post/2015/09/kanban-board/taiga01.jpg)
![TAIGA ScreenShot](/images/post/2015/09/kanban-board/taiga03.jpg)
![TAIGA ScreenShot](/images/post/2015/09/kanban-board/taiga04.jpg)
![TAIGA ScreenShot](/images/post/2015/09/kanban-board/taiga02.jpg)


### ここが良かった

#### アジャイル開発管理に特化したテンプレート

全体を見渡せるかんばんボードだけではなく、
期間区切りのスプリントを作成して、バックログからストーリーカードを割り振り、
各タスクの進捗状況を確認できる`タスクボード`機能。

プロジェクト全体の遅延動向をより正確に把握するために、
ストーリーカード毎に設定するポイント(難度重み付け)[^2]と、
ストーリーカードの進捗に基いて描写される`バーンダウンチャート`。

感覚的には以前使っていた`Redmine`のアジャイル拡張の`Alminium`に似ている。  
(アジャイルの管理ツールって概ねこんな感じなのかな)

[^2]: フィボナッチ数列っぽいものから重みを選択できる。数列は設定から変更可能。


#### ユーザーごとに権限グループ設定をすることができる

スプリントを追加できるのはオーナーのみとか、
エンジニア/デザイナーはタスクのみを登録できる。とか、
グループによって、事細かに権限を設定することができる。

デフォルトの権限グループとしては、`UX`,`DESIGN`,`FRONT`,`BACK`,`PRODUCT OWNER`などがあるが、こちらも設定で変更できるっぽい。



### 微妙なところ

#### 軽めに使うには複雑すぎるか

`Redmine`拡張の`Alminium`を使った時も思ったことだが、
メンバーがアジャイル開発手法に慣れていない場合、
バックログ > スプリント > タスクボードの階層構造に少し戸惑うかもしれない。

一応、設定からアジャイル開発系のモジュールを無効にできたりするが、
かんばんボードの列名を別の設定画面で行う必要があったりと、少し面倒くさい。
シンプルなTODO表として使うなら、`Trello`,`Wekan`とかの方がとっつきやすいかもしれない。



Wekan - お手軽かんばん式プロジェクト管理
------------------------------

ちょっと前は、`Libreboard`と呼ばれていて、日本語の紹介サイトも豊富に存在した。
その頃はボード画面から設定画面から、何から何までTrelloにそっくりだったが、
`Wekan`に名を変えてから、少しUIにオリジナリティが増したように感じる。

![Wekan ScreenShot](/images/post/2015/09/kanban-board/wekan01.jpg)
![Wekan ScreenShot](/images/post/2015/09/kanban-board/wekan02.jpg)


### ここが良かった

#### シンプル・イズ・ベスト

`Trello`の基本機能から、更に必要最低限のものに絞ってるので、非常にとっつきやすい。
システム開発に限らず、シンプルなTODO管理にも使えそう。
ひょっとすると、ITアレルギー持ちの老若男女にも使っていただけるかもしれない。

こういうツールの真髄は、**今どんな課題があるか。どういう状況か。誰が着手してるか。**を素早く把握することにあるので、
コミュニケーションツールとして割り切るならば、十分だとは思う。

#### 日本語UIに対応

上のログイン画面のスクリーンショットのとおり、デフォルトで日本語に対応している。
ログイン後の画面も右上メニューの`Change Languege`から日本語にできる。
英語アレルギー持ちの老若男女にも使っていただけるだろう。


### 微妙なところ

#### アジャイル開発管理に使うにはシンプルすぎるか

本格的にアジャイル開発に使うには、複数ボードにまたいだりと、
運用テクニックが必要になりそう。
あと、`Trello`や`Restyaboard`にあるようなチェックリスト機能がないので、
各ストーリーカードの進行状況(タスク状況)をボード上から確認するのは難しい。



Restyaboard - 多機能かんばん式プロジェクト管理
------------------------------

基本的には`Trello`クローンなのだが、
シンプル化の`Wekan`と違い、多機能化を目指している。

![Restyaboard ScreenShot](/images/post/2015/09/kanban-board/restya01.jpg)
![Restyaboard ScreenShot](/images/post/2015/09/kanban-board/restya02.jpg)
![Restyaboard ScreenShot](/images/post/2015/09/kanban-board/restya03.jpg)


### ここが良かった

#### 他ツールにない前衛的な機能やTrello有料機能が使えたりする

例えば、ボードのオーナー以外がストーリーカードを追加することができないが、
ボード一覧による進捗状況確認、カレンダー表示、デスクトップ通知[^3]、ファビコンに新着通知数表示など、他ツールにない前衛的な機能/UIが豊富。

チェックリスト、Due Date、ボードの背景に写真が使える、などを見ると、
機能面では`Wekan`より、こちらのほうが`Trello`を意識しているかも。
また、`Trello`からデータをインポートする機能が付いているので、
もし無償版では満足できなくなったら、試してみるのもいいかもしれない。

[^3]: Trelloにもデスクトップ通知機能は付いているみたい。[[参考]](http://n2p.co.jp/blog/planning/trellotips/)


### 微妙なところ

#### ユーザーインタフェースに少し難あり

定期的に再読み込みのロードバーが表示されたり、
デスクトップ通知が絶え間なく表示されたり、
ストーリーカードの詳細ポップアップがグィングイン動いたり、
若干UI効果がうるさいかも。

[GitHub](https://github.com/RestyaPlatform/board)を見るに、機能面含めて現在開発中のアルファ版という位置づけと思われるので、
今後のバージョンアップに期待したいところ。


あとがき
------------------------------

１年ほど前にOSSのかんばんツールを探してた時は、
`Redmine`の`Alminium`ぐらいしか選択肢がなかった気がしたが、
ものすごいスピードで新サービスが生まれるWeb系の恐ろしさを感じる。

OSS作者様に感謝すると共に、自分もなにか残してえなあ。と色々弄ってて思った。