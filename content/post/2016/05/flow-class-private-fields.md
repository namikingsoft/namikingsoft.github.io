---
Categories:
  - 静的型付け言語
Tags:
  - JavaScript
  - ECMAScript
  - flow
  - flowtype
  - DDD
date: 2016-05-12T08:00:00+09:00
title: 静的型チェッカーflowのクラスでPrivateなフィールドを定義するメモ
---

[flow](http://flowtype.org/)はJavaScriptの型チェッカーだが、TypeScriptみたくPrivateフィールドを定義できるわけではなく、ちょっとした工夫が必要だったので、メモ。

* [flowのmunge_underscoresオプションを使う方法](#munge)
* [ES6のWeakMapを使う方法](#weakmap)


### なんでPrivateフィールドが必要？

* インスタンス生成後に外部からフィールド値を変更させたくないため。
  * **ドメイン駆動設計**(DDD)的なクラス設計をしていると、**イミュータブル(不変)**のエンティティや値オブジェクトのようなものを多用する。
  * イミュータブルであることを保証できれば、安心してインスタンスを参照で保持できる。(DeepCopyをする必要がなくなる)
* Public箇所(API)を最小限にしておおきたい。
  * リファクタリングやテスト記述が楽になる。

などなど。



<a name="munge"></a>
## flowのmunge_underscoresオプションを使う方法

flowオプションの[munge_underscores](http://flowtype.org/docs/advanced-configuration.html)を有効にすると、先頭に`_`(アンダースコア)を付けたフィールド/メソッドは、継承先で使えない。というルールを追加することができる。

### .flowconfig 追記

```diff
[options]
+ munge_underscores=true
```

### 実装例

[GitHub上の使用例](https://github.com/facebook/flow/blob/7e35d0bd45db81826868022b644c2c2b2b60c895/tests/class_munging/with_munging.js)を参考にして、Privateフィールドを実現してみる。

```typescript
// @flow

type Param = {
  field1: number,
  field2: string,
}

class PrivateSample {
  _param: Param;

  constructor(param: Param) {
    this._param = param;
  }

  getField1(): number {
    return this._param.field1;
  }

  _getField2(): string {
    return this._param.field2;
  }
}

export default class Sample extends PrivateSample {}
```

実際にflowをかけると、以下の様なエラーになる。

```typescript
const sample = new Sample({
  field1: 5,
  field2: "test",
})
assert(instance.getField1() === 5) // OK
assert(instance._getField2() === "test") // NG
assert(instance._param.field1 === 5) // NG
```
```
error| property `_param` Property not found in (:0:1,0) Sample
```

先頭に`_`(アンダースコア)、ハンガリアン記法的なキモさがあって、あまり使いたくないが、一番flowっぽい解決法といえる。

### 継承元のクラスを直接インスタンス化すると使えちゃう

ちなみに、継承元の`PrivateSample`を直接使うと、エラーは出ない。継承しないと効果がないみたいなので、継承元のクラスは`export`しないほうが良さそう。

```
const sample = new PrivateSample({
  field1: 5,
  field2: "test",
})
assert(instance.getField1() === 5) // OK
assert(instance._getField2() === "test") // NG
assert(instance._param.field1 === 5) // NG
```



<a name="weakmap"></a>
## ES6のWeakMapを使う方法

flowに限ったものではないが、ES6でPrivateなフィールドを定義する方法論がある。

> ES6 class での private プロパティの定義  
> http://qiita.com/k_ui/items/889ec276fc04b1448674

Symbolアクセスを使う方法は、`Object.getOwnPropertySymbols`を使えば、外部から値を変更することが可能なため、今回は避けた。

WeakMapでも同じファイル内ならアクセスできるが、インスタンスを作るのは概ね別ファイルなので、あまり問題ないと思った。

### 実装例

```typescript
// @flow

type Param = {
  field1: number,
  field2: string,
}

const privates: WeakMap<Object, Param> = new WeakMap();

export default class Sample {

  constructor(param: Param) {
    privates.set(this, param);
  }

  getField1(): number {
    return privates.get(this).field1;
  }

  getField2(): string {
    return privates.get(this).field2;
  }
}
```


### コンソールデバッグがしづらい

WeakMapの方法で、Privateフィールド化していると、コンソールでのデバッグに苦労する。
```typescript
const sample = new Sample({
  field1: 5,
  field2: "test",
});
console.log(sample);
```
としても、フィールドの内容は表示されず、以下の様なダンプに。
```
Sample {}
```
実質、インスタンス内のプロパティには含まれていないので、表示出ないのは当たり前ではある。`privates`のWeakMapをダンプすれば、以下の様な表示はされるが、ファイル外からでは参照できないので、厳しい。
```
WeakMap {Sample {} => Object {field1: 1234, field2: "test"}}
```


### [おまけ] Privateなメソッドも定義できる？

同ファイル内のClass外に関数を定義して、Classメソッド内で使えば実現できなくもない。

```diff
const privates: WeakMap<Object, Param> = new WeakMap();

export default class Sample {

  constructor(param: Param) {
    privates.set(this, param);
  }

  getField1(): number {
    return privates.get(this).field1;
  }

  getField2(): string {
    return privates.get(this).field2;
  }
+
+  getPowField1(num: number) {
+    return powField1(this, num);
+  }
}

+// Private method
+function powField1(instance: Sample, num: number) {
+  return Math.pow(privates.get(instance).field1, num);
+}
```

ただ、ESLintを併用していると、`no-use-before-define`に引っかかったりする。
ちとまどろっこしいね。



## 備考

コンストラクタ引数にObjectを渡して、WeakMapにそのままセットする。名前引数的に使えるので、コードの見通しがよくなる。

```typescript
const sample = new Sample({
  field1: 1234,
  field2: "Text",
});
```

ただし、コンストラクタ引数へ渡すObjectを変更可能にしておくと、イミュータブルじゃなくなってしまうので、注意。

```typescript
let param = {
  field1: 1234,
  field2: "Text",
};
const sample = new Sample(param);

// non-immutable
param.field1 = 2345;

```

コンストラクタ内で、ObjectのShallowCopyを行うなどして、対策すると良いかもしれない。

```typescript
constructor(param: Param) {
  // ES7の`object-rest-spread`を使うと楽
  Sample.privates.set(this, { ...param });
}
```


## まとめ

JavaScriptの言語仕様上、Private関係は実装しにくく、どうしてもまどろっこしい書き方になってしまう。それでも、TypeScriptを含め、様々なトランスパイラが生まれた今、以前に比べれば、ずいぶんとPrivateを実現しやすくなったと思う。

> JavaScriptとprivateの見果てぬ夢  
> http://blog.tojiru.net/article/238901975.html

言語仕様を超える夢を見て、戦い続けた男たちに敬意を表したい。

