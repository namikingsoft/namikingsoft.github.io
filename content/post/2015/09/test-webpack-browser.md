---
Categories:
  - フロントエンド関連
Tags:
  - webpack
  - webpack-dev-server
  - Mocha
date: 2015-09-11T08:30:23+09:00
title: フロントエンドの継続的テストをMocha+webpack+ブラウザでやってみる
---

webpackの[Testing](http://webpack.github.io/docs/testing.html)を眺めてたら、
ブラウザ上でアプリを動作させながらMochaのSpecを走らせて、
クライアントサイドのテストをする、
みたいなことが手軽に出来そうだったので、やってみた。

**webpack-dev-server**を利用すれば、
ソースやテストを修正直後に自動リロードされるので、
継続的テストみたいな手法もとりやすい。

![ScreenShot](/images/post/2015/09/test-webpack-browser/index.jpg)



### 動作サンプル

ひと通り動くサンプルを作ったので、以下のGitHubに上げておきます。
nodeやnpmがインストールされていれば、動作すると思われます。

"Greetingボタンを押したら、その下に挨拶が追加される"  
みたいな動作のサンプルアプリとそのSpecをjQueryでシンプルに組んであります。

> GitHub: sample-webpack-test  
https://github.com/namikingsoft/sample-webpack-test



### ざっくり解説

#### ファイル構成
```
sample-webpack-test
├── build
│   ├── app.js // webpackが吐き出したアプリ本体のバンドルJS。
│   ├── index.html // アプリとSpecを動作させるHTML
│   └── spec.js  // webpackが吐き出したSpecのバンドルJS。
├── spec // このディレクトリ以下に置いた*Spec.jsが実行される
│   └── mainSpec.js 
├── src
│   └── main.js // アプリ本体のソース
└── webpack.config.js // webpackの設定ファイル
```

`build`ディレクトリ内の`app.js`と`spec.js`は、
webpack-dev-server内の動作であれば、
メモリ内のものが呼び出されるようなので、特に設置する必要はなさそう。


#### 複数のSpecファイルに対応する

npmのglobモジュールを利用して、
複数のSpecファイルをエントリーポイントに含めることができる。
また、requireでglobを書きたい場合は、[glob-loader](https://github.com/seanchas116/glob-loader)を使えば、同じようなことができる。

```javascript
// webpack.config.jsのmodule.exports内

entry: {
  app: "./src/main.js",
  spec: glob.sync("./spec/**/*Spec.js"),
}
```


#### 修正後に自動的にテストが走るようにする

webpack-dev-serverには、ファイル修正を検知して再読み込みをしてくれる、
hotモードという機能が付いているので、webpack.config.jsでそれをを有効にする。

```javascript
// webpack.config.jsのmodule.exports内

devServer: {
  // Document Root
  contentBase: "./build",
  // 動作ポート指定
  port: 8080,
  // hotモード有効化
  hot: true,
  // これがないと、ブラウザで
  inline: true,
},
plugins: [
  // hotモードに必要なプラグイン
  new webpack.HotModuleReplacementPlugin(),
],
```


#### Specファイルをブラウザで動作するように変換する
webpackの[Testing](http://webpack.github.io/docs/testing.html)のページにもあるが、
mocha-loaderを噛ますことで、ブラウザでMochaが利用可能になるJSが吐き出せるようになる。

SpecファイルをES6で書きたければ、
babel-loaderを挟むと、一般ブラウザ用のJSに変換できる。
CoffeeScript+Chaiとかで書いても気持ちよさそう。

```javascript
// webpack.config.jsのmodule.exports内

module: {
  loaders: [
    // App用
    {
      test: /\.js$/,
      loaders: ['babel'],
      exclude: /(node_modules|bower_components)/,
    },
    // Spec用
    {
      test: /Spec\.js$/,
      loaders: ['mocha', 'babel'],
      exclude: /(node_modules|bower_components)/,
    },
  ],
},
```


#### AppとSpecを同時に走らせるHTMLを用意

アプリの動作画面にSpec結果のレイアウトを入れ込む。  
`app.js`で必要なUIを書き出すなどの初期処理を行ってから、`spec.js`を走らせている。

```html
<!-- build/index.html -->

<!DOCTYPE html>
<html lang="ja">
  <head>
    <meta charset="UTF-8">
    <title>App</title>
    <style>
      /* Spec実行結果を表示するレイアウトCSS */
      .layout-spec {
        position: fixed;
        overflow: scroll;
        top: 0; bottom: 0; right: 0;
        width: 45%;
        background-color: #eee;
      }
      .layout-spec pre {
        background-color: #fff;
      }
    </style>
  </head>
  <body>
    <!-- App実行 -->
    <script src="app.js"></script>
    <div class="layout-spec">
      <!-- Spec実行 -->
      <script src="spec.js"></script>
    </div>
  </body>
</html>
```


### 試しにブラウザで動かしてみる

GitHub上の[動作サンプル](https://github.com/namikingsoft/sample-webpack-test)をcloneして、
webpack-dev-serverを起動したら、
お使いのブラウザから以下のURLにアクセスすることで動作を確認できる。

http://localhost:8080/webpack-dev-server/

#### コマンド例

```bash
git clone https://github.com/namikingsoft/sample-webpack-test
cd sample-webpack-test
npm install && npm start
open http://localhost:8080/webpack-dev-server/
```

#### 動作画面の例

フロントエンドアプリとMochaのSpecを同時に動かしている図。
Seleniumみたいにギュンギュン動いて楽しい。
Mochaのテスト中にに割り込んでワザとテストを失敗させたりできる。

![Animation](/images/post/2015/09/test-webpack-browser/animation.gif)

Specは走らなくていいから、
アプリの動作確認だけしたいときは以下のURL[^1]で可能。
http://localhost:8081/webpack-dev-server/app

[^1]: URLの`app`は`webpack.config.js`のentry項目で設定した連想配列のキー。HTMLはwebpack-dev-serverがメモリ内で自動生成してくれる。



### あとがき

ChromeとかFirefoxなどの複数のブラウザ上で手軽にフロント動作仕様を自動チェックしたい、
みたいなときの方法論の一つとして紹介してみた。

ただ、CLI動作とかCIと連携する場合は、
Kermaのようなテストランナーを使ったほうが良いかも。
webpackはKermaとも簡単に連動できるようなので、
その辺も後々まとめておきたい。
