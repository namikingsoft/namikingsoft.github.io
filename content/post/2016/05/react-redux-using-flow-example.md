---
Categories:
  - 静的型付け言語
Tags:
  - JavaScript
  - ECMAScript
  - flow
  - flowtype
  - React
  - Redux
date: 2016-05-22T20:00:00+09:00
title: 静的型チェッカーflowでReact+Reduxのサンプルアプリを組んでみた
---

JavaScript型チェッカー[flow](http://flowtype.org/)を使って、React+Reduxで簡単なカウンターのサンプルアプリケーションを組んでみたので、その際のいくつかのポイントなどをまとめておきます。


### サンプルアプリについて

ボタンを押したら数字がインクリメントされるタイプのよくあるサンプルプログラム。

![サンプルアプリPreview](/images/post/2016/05/react-redux-flow-sample/preview.gif)

> GitHub: namikingsoft/react-redux-using-flow-example
> https://github.com/namikingsoft/react-redux-using-flow-example

#### ソース周りのファイル構成
```sh
react-redux-using-flow-example
|-- src
|   |-- actions
|   |   `-- counter.js         # カウンターアクションの定義
|   |-- components
|   |   `-- Button.js          # ボタン用コンポーネント
|   |-- containers
|   |   `-- LayoutContainer.js # 各ページの側端コンテナ
|   |-- declares               # 外部モジュールの型定義 (ほぼanyをexports)
|   |   `-- ****.js
|   |-- index.html             # ベースHTML
|   |-- index.js               # フロント側エンドポイント
|   |-- pages
|   |   |-- CounterPage.js     # カウンターページ
|   |   |-- HelloPage.js       # 挨拶用ページ
|   |   `-- TopPage.js         # トップページ
|   |-- reducers
|   |   |-- counter.js         # カウンターReducer
|   |   `-- index.js           # Reducerのインデックス
|   |-- sagas
|   |   |-- counter.js         # カウンターの非同期処理
|   |   `-- index.js           # 非同期処理のインデックス
|   |-- server.js              # サーバー側エンドポイント
|   `-- types
|       |-- Action.js          # Action(Fluxスタンダード)の型定義
|       `-- Counter.js         # カウンター関連の型定義
`-- package.json
```

非同期周りの処理に[redux-saga](https://github.com/yelouafi/redux-saga)を使ってますが、今回はその辺りの解説は省きます。



## ポイントいくつか

サンプルアプリ実装の際に、工夫した点/苦労した点を以下にまとめておきました。


### StateやActionの型定義をする
ReduxのStateやActionのPayload値は、動的言語らしく何でも入れる事が可能です。一人で開発するのなら良いですが、複数人で開発する場合、**Action->Reducer->Viewで引き回す型の認識が合わず、思わぬバグが発生**しかねません。

なるべく一つの型定義を使いまわし、値の引き回しに規約を与える必要があります。

#### FluxスタンダードなAction型の定義
```typescript
// src/types/Action.js
export interface Action {
  type: string;
  error?: boolean;
  meta?: any;
}

export interface PayloadAction<T> extends Action {
  payload: T;
}
```
Action関数が返すべきオブジェクトの型定義をします。

> GitHub: acdlite/flux-standard-action  
> https://github.com/acdlite/flux-standard-action

非公式ではありますが、HumanフレンドリーなAction型として定評のあるFluxスタンダードに沿う形のAction型を組みました。

個人的に、PayloadがあるActionとないActionとで、型を分けたかったので、分離してあります。Payloadに使う型は以下項目のように、ジェネリクスで指定できます。

#### Counter関連の型を定義する
```typescript
// src/types/Counter.js
import type { Action, PayloadAction } from "types/Action"

export interface CounterState {
  num: number;
}

export interface IncrementPayload {
  num: number;
}

export interface IncrementAction extends PayloadAction<IncrementPayload> {}
export interface ResetAction extends Action {}
export type CounterAction = IncrementAction & ResetAction
```
StateやActionの型を一つのファイルに定義しておきます。


### 定義した型をActionやReducerで使い回す

上で定義した共通の型設定をAction関数やReducer関数で読み込みます。

#### Action関数の定義で使い回す
```typescript
// src/actions/counter.js
import type { IncrementAction, ResetAction } from "types/Counter"

export const REQUEST_INCREMENT = "COUNTER__REQUEST_INCREMENT"
export const EXECUTE_INCREMENT = "COUNTER__EXECUTE_INCREMENT"
export const RESET = "COUNTER__RESET"

export function requestIncrement(num: number): IncrementAction {
  return { type: REQUEST_INCREMENT, payload: { num } }
}

export function executeIncrement(num: number): IncrementAction {
  return { type: EXECUTE_INCREMENT, payload: { num } }
}

export function reset(): ResetAction {
  return { type: RESET }
}
```
`src/types/Counter.js`で定義したものを返り値の型として使いまわしています。Action関数ごとに型定義をするかしないかは、個人の好みとなります。

#### Reducer関数の定義で使い回す
```typescript
import { EXECUTE_INCREMENT, RESET } from "actions/counter"
import type { CounterState, CounterAction } from "types/Counter"

export const initialState: CounterState = { num: 0 }

export default function counter(
  state: CounterState = initialState,
  action: CounterAction,
): CounterState {
  switch (action.type) {
    case EXECUTE_INCREMENT: {
      return { num: state.num + action.payload.num }
    }
    case RESET: {
      return { ...initialState }
    }
    default: {
      return state
    }
  }
}
```

Actionで使っている`CounterAction`は全てのAction関数の返り値型をIntersectionした型です。
```typescript
export type CounterAction = IncrementAction & ResetAction
```
以下のように、Unionにしてもよいのですが、
```typescript
export type CounterAction = IncrementAction | ResetAction
```
payloadキーが存在するかしないか、逐一チェックする必要があるため、めんどうです。
```typescript
case EXECUTE_INCREMENT: {
  const incrementNum = action.payload ? action.payload.num || 0 : 0
  return { num: state.num + incrementNum }
}
```


### コンポーネントのProps型はプロパティ変数で定義
`props`というプロパティ変数に型をつけることで、ReactのPropTypesのようなチェックをできます。PropTypesは定義方法(isRequredとか)が独特な点、ランタイムエラーしかでない点で、個人的には使いづらい印象でした。

flowの`props`プロパティを利用すれば、実行前の型チェック時にエラーが出るため、見逃しづらいのと、型定義もflowと同様な方法でできるので、統一感が出ます。

#### コンポーネントのプロパティ変数でPropsの型定義ができる
```typescript
// src/pages/CounterPage.js を改変
class CounterPage extends Component {
  props: {
    counter: CounterState, // クラス型やオブジェクト型も指定しやすい
    dispatch: (action: Action) => any, // 関数型も定義可能
    num?: number, // 任意項目については、プロパティ名後ろに`?`をつける
  };
  // ...
  render() {
    const { counter } = this.props // connectしたCounterState型
    const { hoge } = this.props // Err! 未定義のプロパティは取り出せない
    // ...
  }
}
```
```typescript
// 使う側の例
render() {
  return <CounterPage num="String" /> // Err! 型に合わないプロパティは設定できない
}
```


### コンポーネント内で使うActionはconnectしない
`react-redux`のconnectで、Action関数をpropsに関連付けてしまうと、自分で定義した型情報が消し飛んでしまうので、コンポーネントのPropsで、Action関数の型を再定義する必要があります。

それは面倒＆冗長なので、直接Action関数を使い、その返り値をdispatchすれば、Action関数の元の型定義を使いまわせます。

#### dispatch関数を直接propsに回す
```typescript
// src/pages/CounterPage.js
export default connect(
  ({ counter }) => ({ counter }),
)(CounterPage)
// 第二引数に何も書かなければ、dispatch関数が直接、propsに渡される
```

#### action関数をconnectを通さないことで、元の型定義のまま使える
```typescript
// src/pages/CounterPage.js
import * as actions from "actions/counter"
```
```typescript
handlePressIncrement() {
  const { dispatch } = this.props
  dispatch(actions.executeIncrement(1)) // ここ
}
```



## まとめ

React+Reduxでflowを使った型定義の方法をまとめました。

* StateやActionの型定義をする
* 定義した型をActionやReducerで使い回す
* コンポーネントのProps型はプロパティ変数で定義
* コンポーネント内で使うActionはconnectしない

今回はあまり使いませんでしたが、業務ドメイン関係の型定義(ActionのPayloadやStateの中で使う型)は、Reduxなどのフレームワークに依存せず、別フレームワークでも使いまわせる可能性があるので、積極的に型定義をしていきたいです。
