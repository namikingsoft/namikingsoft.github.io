---
Categories:
  - サーバーサイドReact
Tags:
  - React
  - Express
  - Webpack
  - ECMAScript
  - TypeScript
date: 2016-02-13T07:30:00+09:00
title: サーバーサイドReactをwebpackを使って最小構成で試す (ES6 ＆ TypeScript)
---

サーバーサイドのReactに触れたことがなかったので、React+Express+webpackで試してみた。今回試行した手順をチュートリアル的にまとめておく。まずは、シンプルにできそうなECMAScript6で試して、後半にTypeScriptで組んだソースも、おまけ的に載せておきます。

### この記事の方針

* クライアント -> サーバーサイド -> 結びつける。の順に実装を行う
* なるべくシンプルにするために、実用構成というよりは、最小構成で動かす。
  * コンポーネントのプリレンダやState遷移の確認までを行う。
  * サーバーAPIとの通信や画面遷移は、今回扱わない。

#### 実装するサンプルアプリの内容

チュートリアルでよくありそうな、シンプルなカウンターアプリを動かす。
![Sample](/images/post/2016/02/react-server-using-webpack/sample.png)


#### 事前に必要なソフトウェア

* node.js (v5.6.0)
* npm (v3.6.0)

現時点の安定版を使ってみたが、そこまで新しくなくても問題ない。


#### [Memo] 利用したnpmパッケージのバージョン
```json
"dependencies": {
  "express": "^4.13.4",
  "react": "^0.14.7",
  "react-dom": "^0.14.7"
},
"devDependencies": {
  "babel-cli": "^6.5.1",
  "babel-loader": "^6.2.2",
  "babel-preset-es2015": "^6.5.0",
  "babel-preset-react": "^6.5.0",
  "dtsm": "^0.13.0",
  "ts-loader": "^0.8.1",
  "typescript": "^1.7.5",
  "webpack": "^1.12.13"
}
```
バージョンが新しくなったりすると、この記事の書き方と変わってくる可能性があるので、注意。



ECMAScript6 版 (チュートリアル)
------------------------------
Reactドキュメントの[Getting Started](https://facebook.github.io/react/docs/getting-started.html)でも、Babelを利用しているようなので、まずは、Babelを使って、ECMAScript6で記述できるようにしてみる。なお、サンプルソースの完成版を以下のリポジトリに置いといたので、参考にされたい。

* ECMAScript6版サンプルソースの完成版  
  https://github.com/namikingsoft/sample-react-server/tree/typescript


### まずはクライアント側で動かしてみる
ファイル構成は以下の様な感じになるように、作業をすすめる。

```axapta
react-server
|-- .babelrc            # Babel設定
|-- package.json        # npm設定
|-- public
|   |-- client.js       # webpackによって吐き出されたフロント用のJS
|   `-- test.html       # クライアント確認用
|-- src
|   |-- client.js       # クライアントJSエントリーポイント
|   `-- components
|       `-- Counter.js  # カウンター用Reactコンポネント
`-- webpack.config.js   # webpack設定
```

#### npm init
```sh
mkdir react-server
cd react-server

npm init
```
適当なディレクトリを作り、package.jsonのテンプレートを作っておく。`npm init`の選択肢も全て空Enterで問題ない。

#### 必要なnpmパッケージをインストール
```sh
npm install --save react react-dom
npm install --save-dev webpack babel-loader babel-preset-es2015 babel-preset-react
```
モダンブラウザによっては、`babel-preset-es2015`はいらないかもだが、一応。



#### webpack.config.js
```sh
var webpack = require('webpack');

module.exports = {
  entry: {
    client: "./src/client.js",
  },
  output: {
    filename: '[name].js',
    path: "./public",
  },
  module: {
    loaders: [
      {
        test: /\.jsx?$/,
        loaders: ['babel'],
        exclude: /node_modules/,
      },
    ],
  },
  resolve: {
    extensions: ['', '.js', '.jsx'],
    modulesDirectories: ['node_modules'],
  },
};
```
なるべくシンプルにするため、HotLoaderなど記述は入れていない。


#### .babelrc
```sh
{
  "presets": ["es2015", "react"],
}
```
Babelの設定ファイル。`React -> ES6 -> ES5`のような感じで、どのブラウザでも割りかし動作するように変換する。

#### public/test.html
```html
<!DOCTYPE html>
<html>
  <head>
    <title>App</title>
  </head>
  <body>
    <div id="app"></div>
    <script src="app.js"></script>
  </body>
</html>
```
クライアントJSの動作確認用HTML。`app.js`が実行された後に、`<div id="app"></div>`の中身がCounterコンポーネントに置き換わる。


#### src/client.js
```javascript
import React from 'react'
import ReactDOM from 'react-dom'
import Counter from './components/Counter'

ReactDOM.render(
  <Counter />,
  document.getElementById('app')
)
```
Counterコンポーネントを`<div id="app" />`に表示する。


#### src/components/Counter.js
```javascript
import React, {Component} from 'react'

export default class Counter extends Component {

  constructor() {
    super()
    this.state = {
      count: 0
    }
  }

  render() {
    return (
      <div>
        <p>Count: {this.state.count}</p>
        <button onClick={e => this.increment()}>Increment</button>
      </div>
    )
  }

  increment() {
    this.setState({
      count: this.state.count + 1
    })
  }
}
```
Incrementボタンを押したら、内部Stateが変化して、コンポーネントを再描写される。


#### webpack実行
```sh
./node_modules/.bin/webpack
```
これで、`public/client.js`にブラウザで動作するJSが生成される。

webpackコマンドについては、`npm run build`コマンドで実行できるように、package.jsonのscriptsに登録しておくと良いかも。
```json
"scripts": {
  "build": "webpack"
}
```
```sh
npm run build
```


#### 動作確認
Incrementボタンを押して、Stateの変動やコンポーネントの再描写が確認できる。
![Client Result](/images/post/2016/02/react-server-using-webpack/client-result.png)


### サーバーサイドからコンポーネントを描写する
ファイル構成としては以下。`src/server.js`が追加されただけ。
```axapta
react-server
|-- package.json
|-- public
|   |-- client.js
|   `-- test.html
|-- src
|   |-- client.js
|   |-- components
|   |   `-- Counter.js
|   `-- server.js     # 追加: ExpressでCounterコンポーネントをプリレンダリング
`-- webpack.config.js
```


#### 必要なnpmパッケージをインストール
```sh
npm install --save express
npm install --save-dev babel-cli
```
軽量Webフレームワークの`express`と、node.jsの実行をbabelに通すための`babel-cli`をインストールする。


#### src/server.js
```javascript
import express from 'express'
import React from 'react'
import ReactDOMServer from 'react-dom/server'
import Counter from './components/Counter'

// init express
const app = express()

// add top page routing
app.get('/', (req, res) => {
  res.send(
    ReactDOMServer.renderToString(
      <Counter />
    )
  )
})

// start listen
app.listen(3000, () => {
  console.log('Example app listening on port 3000!');
})
```
`ReactDOMServer.renderToString()`を使って、コンポーネントをプリレンダリングできる。  
(HTMLの側端は端折ってます)

#### サーバー起動
```sh
node_modules/.bin/babel-node src/server.js
```
`babel-node`はbabel-cliでインストールされるコマンドで、実行対象のJSを自動的にBabel変換した上でnodeコマンドを実行してくれる便利なラッパー。

ビルドと同じく、`npm start`コマンドで実行できるように、package.jsonのscriptsに登録しておくと良い。
```json
"scripts": {
  ...
  "start": "babel-node src/server.js"
}
```
```sh
npm start
```

#### 動作確認
```sh
open http://localhost:3000
```
クライアントのみの実行と、全く同じ画面が表示される。ブラウザのソース表示やcurlなどからも、コンポーネントの中身がプリレンダリングされたHTMLを確認できた。

しかし。

![Client Result](/images/post/2016/02/react-server-using-webpack/server-result.png)

サーバーサイドでプリレンダしただけで、クライアントでは何もしてないし、react.jsも読み込んでないため、と思われる。


### サーバーサイドとクライアントの処理をつなげる
Fluxフレームワークで有名なReduxのドキュメントの[Server Rendering](https://github.com/rackt/redux/blob/master/docs/recipes/ServerRendering.md)を見るに、サーバーサイドでプリレンダした要素に、再度クライアントからレンダリングをかけている様な処理になっていたので、試してみる。

#### src/server.js の修正
```diff
import express from 'express'
import React from 'react'
import ReactDOMServer from 'react-dom/server'
import Counter from './components/Counter'

// init express
const app = express()

+ // add static path
+ app.use(express.static('public'))

// add top page routing
app.get('/', (req, res) => {
  res.send(
    ReactDOMServer.renderToString(
-      <Counter />
+      <div>
+        <div id="app">
+          <Counter />
+        </div>
+        <script src="client.js" />
+      </div>
    )
  )
})

// start listen
app.listen(3000, () => {
  console.log('Example app listening on port 3000!');
})
```

`app.use(express.static('public'))`で、publicディレクトリ以下のファイルを静的ファイルとして、読み込み可能として、プリレンダする内容をクライアント側の時に試した`test.html`と同じような記述に変更する。


#### 再度、動作確認
```sh
npm start
open http://localhost:3000
```
今度は、Incrementボタン押下で、正常動作を確認できるはず。



TypeScript 版 (要約)
------------------------------
型がついていないと落ち着かない自分のためにも、TypeScriptで導入できるようにもしておきたい。クライアント側は`ts-loader`を挟むぐらいで概ね対応できるが、サーバーサイドは`babel-node`に相当するものがないようので、一度コンパイルしてから実行するようなイメージ。

* Typescript版サンプルソースの完成版  
  https://github.com/namikingsoft/sample-react-server/tree/typescript

* ECMAScript6版との差分  
  https://github.com/namikingsoft/sample-react-server/compare/typescript


### 要約
TypeScript版については、上のようにチュートリアル形式にはせず、要約解説にしたい。詳しくは上の[ECMAScript6版との差分](https://github.com/namikingsoft/sample-react-server/compare/typescript)を見ていただいたほうが、早いかもしれない。

#### 型定義ファイルマネージャにはdtsmを使った。

npmとほぼ同じインタフェースなので使いやすい。以下コマンド例。

```sh
npm install --save-dev dtsm
export PATH=./node_modules/.bin:$PATH

dtsm init
dtsm install --save react.d.ts
dtsm install --save react-dom.d.ts
dtsm install --save express.d.ts
```

#### サーバーサイドのコンパイルはtscを直接使った。
`babel-node`のようなラッパーコマンドがあることを期待したが、観測内ではなさそうなので、通常通り、`dist`ディレクトリあたりに、コンパイル済みのJSを展開して、`node dist/server.js`みたいにする作戦にした。

tsconfig.jsonは以下のとおり。
```json
{
  "compilerOptions": {
    "target": "es5",
    "jsx": "react",
    "module": "commonjs",
    "moduleResolution": "node",
    "experimentalDecorators": true,
    "outDir": "dist"
  },
  "files": [
    "typings/bundle.d.ts",
    "src/server.tsx"
  ]
}
```
なお、tsconfig.jsonはクライアント側のコンパイルにも使いまわしたいので、React変換なども有効にしてある。`experimentalDecorators`はいらないかもだが、ReduxなどのFluxフレームワークで、割りとデコレータ(@connectなど)が使われていたりするので、一応有効にしてある。

コンパイルについては、package.jsonのscriptsを以下のように修正して、`npm run build`でやると良い。

```diff
"scripts": {
  ...
- "build": "webpack",
+ "build": "webpack && tsc -p .",
  ...
},
```
```sh
npm run build
```

#### クライアントのコンパイルにはwebpackのts-loaderを使った。
webpack.config.jsの修正差分は以下の様な感じになる。なお、TypeScript自体が、`React -> ES6 -> ES5`変換機能を備えているので、無理にBabelに通さなくてもよい。
```diff
var webpack = require('webpack');

module.exports = {
  entry: {
-   client: "./src/client.js",
+   client: "./src/client.tsx",
  },
  output: {
    filename: '[name].js',
    path: "./public",
  },
  module: {
    loaders: [
      {
        test: /\.jsx?$/,
        loaders: ['babel'],
        exclude: /node_modules/,
      },
+     {
+       test: /\.tsx?$/,
+       loaders: ['ts'],
+       exclude: /node_modules/,
+     },
    ],
  },
  resolve: {
-   extensions: ['', '.js', '.jsx'],
+   extensions: ['', '.js', '.jsx', 'ts', '.tsx'],
    modulesDirectories: ['node_modules'],
  },
};
```


あとがき
------------------------------

なるべくシンプルな構成で、サーバーサイドReactを試してみた。

今回はサーバーサイドにExpressを使ってみたが、Railsなどでも、`react-rails`のようなgemを利用して、クライアントとの連携ができるはず。

ReduxやReactRouterなどを利用した、もうちょっと実践的なやり方については、以下のReduxドキュメントやQiita記事が詳しそうだったので、載せておきます。

> Redux: Server Rendering  
> https://github.com/rackt/redux/blob/master/docs/recipes/ServerRendering.md

> Qiita: React + Expressでのサーバーサイドレンダリング方法のまとめ  
> http://qiita.com/hmarui66/items/4f75e624c4f70d596873
