---
Categories:
  - 小ネタ
Tags:
  - パーサーコンビネーター
  - ECMAScript
  - JavaScript
  - npm
  - Bot
date: 2017-11-27T08:00:00+09:00
title: パーサーコンビネーターを使って自然言語風のテキストからパラメーターを抽出する
---

CLI と違い、引数を渡す方法が標準化しておらず、パースを実装する必要があった。Slack の `/remind` スラッシュコマンドのように、自然言語風に Bot へのパラメーターを抽出したい。

```
/remind me to drink water at 3pm every day
/remind me on June 1st to wish Linda happy birthday
/remind #team-alpha to update the project status every Monday at 9am
/remind @jessica about the interview in 3 hours
```

正規表現を使うと複雑になりがちな上のようなパラメーター抽出のため、パーサーコンビネーターを使って、パーサーを実装してみる。


### 実装したいこと

例えば、CircleCI の特定のジョブを Bot を通じて Slack から起動するために、自然言語風のテキストからパラメーターを抽出したい。

```
post build to (username)/(reponame) [on (ブランチ名)] [at (コミットハッシュ)] [for (ジョブ名)]
```

#### パラメーター抽出例

```
post build to namikingsoft/namikingsoft.github.io on master for deploy
```
```json
{
  "repo": "namikingsoft/namikingsoft.github.io",
  "branch": "master",
  "job": "deploy"
}
```


### 実装してみる

上の要件を実装したコード例と軽い解説。

#### 00. ソースコード全体

```typescript
const P = require('parsimmon');
const R = require('ramda');

// map functions
const mapToThirdArg = (_1, _2, _3) => _3;
const mapToRepo = (_1, _2, _3, _4, _5) => `${_1}/${_5}`;
const reduceNodeToObj = R.reduce((acc, x) => R.merge({ [x.name]: x.value })(acc), {});
const transForSentence = R.pipe(mapToThirdArg, reduceNodeToObj);

// atoms
const _ = P.whitespace;
const _o = P.optWhitespace;
const to = P.string('to');
const on = P.string('on');
const at = P.string('at');
const fr = P.string('for'); // TODO: alt `for`
const slash = P.string('/');
const command = P.regex(/post +build/i);
const digit = P.digit;
const letterSmall = P.range('a', 'z');
const letterLarge = P.range('A', 'Z');
const letter = P.alt(letterSmall, letterLarge);
const hex = P.alt(P.range('a', 'f'), digit);
const symbolForSep = P.oneOf('._-');
const symbolForBranch = P.oneOf('._-/#+');

// parameters
const username = P.alt(letter, digit, symbolForSep).many().tie();
const reponame = P.alt(letter, digit, symbolForSep).many().tie();
const branch = P.alt(letter, digit, symbolForBranch).many().tie();
const job = P.alt(letter, digit, symbolForSep).many().tie();
const repo = P.seqMap(username, _o, slash, _o, reponame, mapToRepo);
const revision = hex.many().tie();

// nodes
const nodeRepo = P.seqMap(to, _, repo, mapToThirdArg).node('repo');
const nodeJob = P.seqMap(fr, _, job, mapToThirdArg).node('job');
const nodeBranch = P.seqMap(on, _, branch, mapToThirdArg).node('branch');
const nodeRevision = P.seqMap(at, _, revision, mapToThirdArg).node('revision');
const node = P.alt(nodeRepo, nodeJob, nodeBranch, nodeRevision);
const sentence = P.seqMap(command, _, node.sepBy(_), transForSentence);

// parse
const text1 =
  'post build to namikingsoft/namikingsoft.github.io on master at abcd1234 for deploy';
const text2 =
  'pOSt  BuilD   for   deploy on   master to  namikingsoft  /  namikingsoft.github.io';

sentence.tryParse(text1);
// {
//   "job": "deploy",
//   "revision": "abcd1234",
//   "branch": "master",
//   "repo":"namikingsoft/namikingsoft.github.io"
// }

sentence.tryParse(text2);
// {
//   "job": "deploy",
//   "branch": "master",
//   "repo":"namikingsoft/namikingsoft.github.io"
// }

sentence.tryParse('illegal text example');
// -> Exception!
```

> RunKit でコードを実行する  
> https://runkit.com/namikingsoft/parse-text-for-bot-using-parsimmon


#### 01. 使っている npm モジュール

```typescript
const P = require('parsimmon');
const R = require('ramda');
```


##### Parsimmon - パーサーコンビネーターライブラリ

JS のパーサーコンビネーターライブラリの１つ。Haskell の `Parserc` ライクに使える。

> GitHub: jneen/parsimmon  
> https://github.com/jneen/parsimmon


##### Ramda - 関数型プログラミング支援ライブラリ

関数型プログラミングライブラリの１つ。今回はパーサーの戻り値調整のみに使った。

> Ramda Documentation  
> http://ramdajs.com/


#### 02. 字句の定義

入力文を構成する要素を BNF のような感覚で字句の定義を行っていく。

```typescript
// atoms
const _ = P.whitespace;
const _o = P.optWhitespace;
const to = P.string('to');
const on = P.string('on');
const at = P.string('at');
const fr = P.string('for'); // TODO: alt `for`
const slash = P.string('/');
const command = P.regex(/post +build/i);
const digit = P.digit;
const letterSmall = P.range('a', 'z');
const letterLarge = P.range('A', 'Z');
const letter = P.alt(letterSmall, letterLarge);
const hex = P.alt(P.range('a', 'f'), digit);
const symbolForSep = P.oneOf('._-');
const symbolForBranch = P.oneOf('._-/#+');

// parameters
const username = P.alt(letter, digit, symbolForSep).many().tie();
const reponame = P.alt(letter, digit, symbolForSep).many().tie();
const branch = P.alt(letter, digit, symbolForBranch).many().tie();
const job = P.alt(letter, digit, symbolForSep).many().tie();
const repo = P.seqMap(username, _o, slash, _o, reponame, mapToRepo);
const revision = hex.many().tie();
```

#### 03. パーサーの構築

パーサーを構成する字句を組み合わせたり、関数出力の調整を行う。ノード定義は `alt` を使っても、どの要素が該当したか識別できるするために `node` で名前をつけていくイメージ。

```typescript
// map functions
const mapToThirdArg = (_1, _2, _3) => _3;
const mapToRepo = (_1, _2, _3, _4, _5) => `${_1}/${_5}`;
const reduceNodeToObj = R.reduce((acc, x) => R.merge({ [x.name]: x.value })(acc), {});
const transForSentence = R.pipe(mapToThirdArg, reduceNodeToObj);

// nodes
const nodeRepo = P.seqMap(to, _, repo, mapToThirdArg).node('repo');
const nodeJob = P.seqMap(fr, _, job, mapToThirdArg).node('job');
const nodeBranch = P.seqMap(on, _, branch, mapToThirdArg).node('branch');
const nodeRevision = P.seqMap(at, _, revision, mapToThirdArg).node('revision');
const node = P.alt(nodeRepo, nodeJob, nodeBranch, nodeRevision);
const sentence = P.seqMap(command, _, node.sepBy(_), transForSentence);
```

#### 04. パーサーを使う

定義した構文に沿ったテキストが入力された場合は、ノードの名前をキーとしたオブジェクトとして返され、そうでない場合は**例外が発生**する。

```typescript
// parse
const text1 =
  'post build to namikingsoft/namikingsoft.github.io on master at abcd1234 for deploy';
const text2 =
  'pOSt  BuilD   for   deploy on   master to  namikingsoft  /  namikingsoft.github.io';

sentence.tryParse(text1);
// {
//   "job": "deploy",
//   "revision": "abcd1234",
//   "branch": "master",
//   "repo":"namikingsoft/namikingsoft.github.io"
// }

sentence.tryParse(text2);
// {
//   "job": "deploy",
//   "branch": "master",
//   "repo":"namikingsoft/namikingsoft.github.io"
// }

sentence.tryParse('illegal text example');
// -> Exception!
```


### まとめ

頑張れば正規表現で書けなくもなさそうなテキストパースを、パーサーコンビネーターで書いてみて、思ったこといくつか。

#### 各要素に名前を付けられる ＆ 組み合わせることができる

正規表現で複雑なパーサーを書くと、意味不明な文字列の羅列になりやすく、リーダブルに書くことが難しいが、字句レベルから変数にできて、再利用もしやすい点が良いと感じた。


#### Parsimmon ドキュメントが Parsec より簡潔でわかりやすい

Haskell の Parsec でパーサーを実装していたときは、[Hackage](https://hackage.haskell.org/package/parsec) を見ても、[ググっても](https://www.google.com/search?q=haskell+parsec+documentation)、いまいち使い方がわからず、入門用にまとまっているドキュメントを探すのに苦労したが、[Parsimmon ドキュメント](https://github.com/jneen/parsimmon/blob/master/API.md)はコード例とともに簡潔にまとまっていて、実装がしやすかった。Parsec の練習用にも良いかもしれない。

[Examples](https://github.com/jneen/parsimmon/tree/master/examples) には、軽量スクリプト言語のパーサーや JS Linter の実装例もあったので、より複雑なパーサーを構築したくなったときに参照したい。

