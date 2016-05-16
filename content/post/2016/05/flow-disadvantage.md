---
Categories:
  - 静的型付け言語
Tags:
  - JavaScript
  - ECMAScript
  - flow
  - flowtype
  - ESLint
date: 2016-05-12T07:00:00+09:00
title: 静的型チェッカーflowを使ってみて、微妙に気になったこと４つ
---

[flow](http://flowtype.org/)はJavaScriptの静的型チェックツールの一つ。

同じような静的型関連ツールであるTypeScriptと比較して、ESLintやBabelとの併用がしやすかったり、型付けが強めだったり(初期からnon-nullableに対応)と、受ける恩恵も多い。

が、使っていて「おやっ？」っと思う点もいくつかあったので、まとめてみた。


## 気になったこと４つ

### ESLintとの併用でめんどうな事が多かった

[babel-eslint](https://github.com/babel/babel-eslint)というBabelパーサーを用いれば、概ねのESLintルールがflow文法でも適応できるが、例外もあった。

例えば、インターフェイスの定義の場合、

```typescript
interface I {
  field: number;
  method(): string;
}
```
ESLintの`no-undef`ルールを有効にしていると、以下のエラーが発生する。
```
error| 'I' is not defined. (no-undef)
```
ESLintの誤爆ではあるが、そもそも、`interface`なんて文法はECMAScriptにはないので、対応しろっていうのも無茶な話。

ESLintの`no-undef`まわりを無効にすればエラーは出ないが、有志の方が、flow用のBabelカスタムルールを実装してくれているので、ありがたく利用させていただく。

> GitHub: zertosh/eslint-plugin-flow-vars  
> https://github.com/zertosh/eslint-plugin-flow-vars

このBabelプラグインを使ってカスタムルールを有効にすれば、`no-undef`を無効にすることなく、ESLintとflowを併用できる。

```diff
// .eslintrc.jsの修正例
module.exports = {
  "parser": "babel-eslint",
+ "plugins":
+   "flow-vars",
+ ],
  "rules": {
    "no-undef": 1,
+   "flow-vars/define-flow-type": 1,
+   "flow-vars/use-flow-type": 1,
  },
};
```

その他、いろいろ試行錯誤している時にTwitter上でご教示いただいたPluginも、いくつかのflow用カスタムルールがあった。何かflow+ESLintで不都合があり次第、逐一有効にしていく必要があるかも。

<blockquote class="twitter-tweet" data-conversation="none" data-lang="ja"><p lang="ja" dir="ltr"><a href="https://twitter.com/namikingsoft">@namikingsoft</a> eslint-plugin-babel はすでにお試しでしょうか？ eslint 組込ルールの中で、ECMA標準外の構文に起因する誤検知などに対処しているプラグインです。<a href="https://t.co/CD5p5ejHIq">https://t.co/CD5p5ejHIq</a></p>&mdash; Toru Nagashima (@mysticatea) <a href="https://twitter.com/mysticatea/status/728262384771432448">2016年5月5日</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>


### Babelを通しても、ES6文法で使えないものがある

例えば、**ES6のget/setプロパティ**が使えなかった。

イミュータブルなオブジェクトを作って、Privateな値を返すゲッターを作った際、プロパティのように扱えるので、好んで使っていたが、

```typescript
class A {
  get field(): number {
    return 1234
  }
}

const a = new A()
console.log(a.field)
```

flowに通すと、怒られる。

```
error| get/set properties not yet supported
```


`yet`ってあるので、いずれサポートされるのだろうか。


### ジェネリクスなクラス/関数の使い方次第でエラー

flow的には**Polymorphism**というのかな？  
TypeScriptやJava感覚で以下のように書くと、flowだとSyntaxエラーになった。

```typescript
const map = new Map<string, number>()
```

```
error| Parsing error: Unexpected token
```

そもそもBabelがエラーを吐く。`babel-plugin-transform-flow-strip-types`の限界っぽい。

以下のように書くのがflow流っぽいが、なんか冗長な感じがして、あまり好みじゃない。

```typescript
// 変数定義で型を決めとく
const map: WeakMap<string, number> = new WeakMap()

// 型のキャスト
const map = (new WeakMap(): WeakMap<string, number>)
```


関数の場合も似たようなSyntaxエラーを吐くが、
以下の様な型推論が効く例だと、逆にスマートな感じで良い。

```typescript
function toArray<T>(x: T): Array<T> {
  return [x]
}

// 引数の型(number)を元に、返り値の型(Array<number>)が推論される
const nums = toArray(2)
```

### クラスのフィールド定義などでセミコロンが強制

クラスやインタフェースの定義などで、以下のように書くと、
```typescript
class A {
  num: number

  constructor(num: number) {
    this.number = num
  }
}
```
次のエラーが、constructorの行で発生する。
```
error| Unexpected identifier
```
フィールド定義の行末尾にセミコロン(;)を入れれば、エラーは出ない。
```diff
class A {
- num: number
+ num: number;

  constructor(num: number) {
    this.number = num
  }
}
```
アンチ・セミコロン派には吐きそうなほどキツイ仕様。  
https://github.com/facebook/flow/issues/825




## まとめ
flowを使ってみて、以下４つの気になったことをまとめてみた。

* ESLintとの併用でめんどうな事が多かった
* Babelを通しても、ES6文法で使えないものがある
* ジェネリクスなクラス/関数の使い方次第でエラー
* クラスのフィールド定義などでセミコロンが強制

flowは現在も、定期的にVerUPされているツールなので、今回上げた点もいつの間に修正されているかもしれない。今後も細かく見ていきたい。
