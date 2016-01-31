---
Categories:
  - Sparkで機械学習
Tags:
  - Spark
  - 機械学習
  - 線形回帰
  - 決定木回帰
  - Zeppelin
date: 2016-01-31T23:15:00+09:00
title: Sparkで機械学習： 回帰モデルで値を予測する
---

Apache Spark上にて、簡単なCSVのサンプルデータを取り込み、線形回帰や決定木回帰を利用して、穴が空いた項目を予測するサンプルプログラムを書いてみる。



### サンプルデータ (身体情報から結婚時期を予測する)

実データではありません。入門用にシンプルで法則性のあるデータを探したのですが、なかなか見つからなかったので、自分で訓練用のデータを作ってみた。

題材としては、性別や血液型、身長、体重から、結婚適齢期を予測するみたいなことをやってみる。例えば、以下の様なデータを学習用データとして取り込み、

| 結婚した歳 | 血液型 | 性別 | 身長(cm) | 体重(kg) |
|:----:|:----:|:----:|----:|----:|
| 32歳 | O | 女 | 152 | 60 |
| 42歳 | A | 男 | 180 | 80 |
| 26歳 | O | 男 | 155 | 55 |
| 20歳 | B | 女 | 166 | 55 |
| ... | ... | ... | ... | ... |

以下の「？」になっているところの値を予測する、みたいなことをやってみる。

| 結婚する歳 | 血液型 | 性別 | 身長(cm) | 体重(kg) |
|:----:|:----:|:----:|----:|----:|
| ？ | O | 女 | 152 | 60 |
| ？ | A | 男 | 180 | 80 |

> サンプルデータ： 身体情報から結婚時期を予測する  
> [CSV形式のダウンロード](/files/post/2016/01/spark-mllib-regression/training.csv)

#### データの傾向

ただ無差別にデータを作っても、予測が合ってるかどうかの判断がつかないため、  
以下の様な**事実無根**な法則で値をでっちあげてみた。

* B型は早婚
* O型は晩婚
* AB型はとても早婚
* 女性は早婚
* 肥満とモヤシは晩婚
* 男性の高身長はとても晩婚



### コーディング前の準備

#### Apache Zeppelinのインストール

Spark(ScalaやPython)の記述やその他細かいシェルスクリプトなどの操作をWeb上でインタラクティブに行えるノートブック系OSS[^1]。この記事では、Sparkの操作は基本的にこのソフトを用いてコーディングを行っている。Sparkも一緒に含まれているので、これをローカルにインストールするだけで概ね動くはず。

> Apache Zeppelin (incubating)  
> https://zeppelin.incubator.apache.org/

[^1]: 類似のOSSに、Jupyter(iPython Notebook)やspark-notebookがある。データの加工やモデルのチューニングで試行錯誤することが多いので、こういうソフトはかなり重宝する。
[^2]: インポート/エクスポート機能はZeppelin v0.6からなので、現状(2016/01/31)では、ソースからビルドする必要がある。)



### サンプルデータの取り込み

ここからは、Zeppelin上での作業となる。事前にZeppelinを起動して、適当な新しいノートブックを作成しておく。

#### サンプルデータのダウンロード
```scala
%sh
curl -Lo /tmp/training.csv \
  "http://blog.namiking.net/files/post/2016/01/spark-mllib-regression/training.csv"
```
先ほどのCSV形式のサンプルデータを一時保存領域にダウンロードするシェルスクリプトを記述する。

#### １レコード毎のCaseクラスを作成
```scala
case class Profile(
  marriedAge: Option[Double],
  blood: String,
  sex: String,
  height: Double,
  weight: Double
)
```
CSVデータなどをDataFrame形式に変換する際に必要になる。
`marriedAge`をOption型にしているのは、テストデータを取り込む際に入れる値が無いため。

#### CSVをパースして、DataFrame形式に変換
```scala
var csvRDD = sc.textFile("/tmp/training.csv")
var csvHeadRDD = sc.parallelize(Array(csvRDD.first))
var training = csvRDD
  .subtract(csvHeadRDD) // ヘッダ除去
  .map { line =>
    val cols = line.split(',')
    Profile(
      marriedAge = Some(cols(0).toDouble),
      blood = cols(1),
      sex = cols(2),
      height = cols(3).toDouble,
      weight = cols(4).toDouble
    )
  }.toDF
```
RDDだと、`tail`や`slice`関数みたいなものがなくて、ヘッダ除去程度でもちょっとまどろっこしい。分散処理を考えるとしかたないのだろうか。


#### [おまけ] spark-csvモジュールを使ったサンプルデータの取り込み
先ほどの手順で、サンプルデータの取り込みは完了だが、もう１パターン、CSVのパースやDataFrame変換を手伝ってくれるspark-csvモジュールを使ったCSV取り込みを書いておく。

> Zeppelinはパラグラフごとに実行するしないを制御できるので、別パターンのコードや使わなくなったコードも、そのまま残しておいても支障はない。後になって再利用できたりするので、残しておくと便利かも。

##### 依存モジュールロード
```scala
%dep
z.reset()
z.load("com.databricks:spark-csv_2.11:1.3.0")
```
`%dep`(Dependency)については、Sparkが起動する前に行わないと、以下の様なエラーが出る。
```
Must be used before SparkInterpreter (%spark) initialized
Hint: put this paragraph before any Spark code and restart Zeppelin/Interpreter
```
既に起動してしまっている場合は、Zeppelinを再起動するか、InterpreterページのSpark欄の`restart`ボタンを押下する。


##### spark-csvを使ったCSVの取り込み
```scala
import org.apache.spark.sql.types.{
  StructType,
  StructField,
  StringType,
  DoubleType
}
val customSchema = StructType(Seq(
  StructField("marriedAge", DoubleType, true),
  StructField("blood", StringType, true),
  StructField("sex", StringType, true),
  StructField("height", DoubleType, true),
  StructField("weight", DoubleType, true)
))
val training = sqlContext.read
  .format("com.databricks.spark.csv")
  .option("header", "true")
  .schema(customSchema)
  .load("/tmp/training.csv")
```

CSVのパースやヘッダ除去(項目名に利用)まで自動で行ってくれる。型指定まで自動で行うオプション(inferSchema)もあるが、Double型がInteger型になってしまったので、今回は手動で指定した。


### サンプルデータの前処理

Sparkの機械学習ライブラリでは、各分析アルゴリズムにデータを引き渡す前処理として、特徴データ(血液型、性別、身長、体重)を、まとめてベクトル形式に変換する必要がある。

そういった前処理を楽にするために、前処理や回帰モデル設定、訓練データ取り込みを一貫して行えるspark.mlのPipelineを利用してみる。Pipelineについては、[公式のドキュメント](https://spark.apache.org/docs/1.6.0/ml-guide.html)が詳しい。別サイトに[日本語訳](http://mogile.web.fc2.com/spark/ml-guide.html)もあった。


#### 文字列インデクサ
```scala
import org.apache.spark.ml.feature.StringIndexer

val bloodIndexer = new StringIndexer()
  .setInputCol("blood")
  .setOutputCol("bloodIndex")
val sexIndexer = new StringIndexer()
  .setInputCol("sex")
  .setOutputCol("sexIndex")
```
StringIndexerはパイプラインをつなぐための部品の一つ。`A`,`B`,`O`,`AB`といった文字列のカテゴリデータを`0.0`,`1.0`,`2.0`,`3.0`みたいに実数のインデックスに変換してくれる。

#### 複数項目のベクトル化
```scala
import org.apache.spark.ml.feature.VectorAssembler

val assembler = new VectorAssembler()
  .setInputCols(Array(
    "bloodIndex",
    "sexIndex",
    "height",
    "weight"
  ))
  .setOutputCol("features")
```
VectorAssemblerはパイプラインをつなぐための部品の一つ。複数項目の実数データを一つの特徴ベクトルデータに変換してくれる。

#### ベクトル標準化
```scala
import org.apache.spark.ml.feature.StandardScaler

val scaler = new StandardScaler()
  .setInputCol(assembler.getOutputCol)
  .setOutputCol("scaledFeatures")
```
StandardScalerはパイプラインをつなぐための部品の一つ。基準が違うデータを取り込むと予測が不安定になるため、特徴ベクトルデータを標準化する。

これで前処理のためのパイプライン部品は揃った。



### 線形回帰モデルの作成して、予測値を得る

まずは線形回帰を用いて、値の予測を行うためのモデルを作成する。

#### 線形回帰
```scala
import org.apache.spark.ml.regression.LinearRegression

val regression = new LinearRegression()
  .setLabelCol("marriedAge")
  .setFeaturesCol(scaler.getOutputCol)
```
パイプライン部品の一つ。`setLabelCol`には、予想したい項目を指定する。

#### パイプライン作成
```scala
import org.apache.spark.ml.Pipeline

val pipeline = new Pipeline()
  .setStages(Array(
    bloodIndexer,
    sexIndexer,
    assembler,
    scaler,
    regression
  ))
```
今までのパイプライン部品を繋げて、パイプラインを作成する。

#### クロス検証でチューニング設定をして、モデルを作成
```scala
import org.apache.spark.ml.evaluation.RegressionEvaluator
import org.apache.spark.ml.tuning.{
  ParamGridBuilder,
  CrossValidator
}

val paramGrid = new ParamGridBuilder()
  .addGrid(regression.regParam, Array(0.1, 0.5, 0.01))
  .addGrid(regression.maxIter, Array(10, 100, 1000))
  .build()

val evaluator = new RegressionEvaluator()
  .setLabelCol(regression.getLabelCol)
  .setPredictionCol(regression.getPredictionCol)

val cross = new CrossValidator()
  .setEstimator(pipeline)
  .setEvaluator(evaluator)
  .setEstimatorParamMaps(paramGrid)
  .setNumFolds(3)

val model = cross.fit(training)
```
モデルの精度を検証するために、クロス検証の設定をする。以下のような、めんどくさいチューニング処理を自動で行ってくれる便利な機能。

* `paramGrid`で設定した配列のチューニング値で、全組み合わせのモデルを作成する。
* サンプルデータを訓練データと検証データに分けて、一番精度の高いモデルを選択する。

最終的には`model`変数に最適なモデルが束縛される。

##### ちなみに、クロス検証を行わない場合は
```scala
val model = pipeline.fit(training)
```
パイプラインに直接学習データを突っ込む。

#### テストデータ作成
```scala
var test = sc.parallelize(Seq(
  // A型標準体型男
  Profile(None, "A", "男", 170, 65),
  // B型標準体型男
  Profile(None, "B", "男", 170, 65),
  // O型標準体型男
  Profile(None, "O", "男", 170, 65),
  // AB型標準体型男
  Profile(None, "AB", "男", 170, 65),
  // A型標準体型女
  Profile(None, "A", "女", 160, 50),
  // B型標準体型女
  Profile(None, "B", "女", 160, 50),
  // O型標準体型女
  Profile(None, "O", "女", 160, 50),
  // AB型標準体型女
  Profile(None, "AB", "女", 160, 50),
  // A型もやし男
  Profile(None, "A", "男", 170, 35),
  // A型でぶ男
  Profile(None, "A", "男", 170, 100),
  // A型もやし女
  Profile(None, "A", "女", 170, 35),
  // A型でぶ女
  Profile(None, "A", "女", 170, 100),
  // A型高身長男
  Profile(None, "A", "男", 190, 80),
  // A型小人(男)
  Profile(None, "A", "男", 17, 6),
  // A型巨人(男)
  Profile(None, "A", "男", 17000, 6500)
)).toDF
```

学習データの特徴データから大幅に外れるデータの予測も下の方に入れてみた。

#### モデルから予測値を得る
```scala
model.transform(test)
  .select("blood", "sex", "height", "weight", "prediction").show
```
```
+-----+---+-------+------+------------------+
|blood|sex| height|weight|        prediction|
+-----+---+-------+------+------------------+
|    A|  男|  170.0|  65.0| 32.79763046781005|
|    B|  男|  170.0|  65.0|32.810260236687924|
|    O|  男|  170.0|  65.0|   32.803945352249|
|   AB|  男|  170.0|  65.0| 32.79131558337113|
|    A|  女|  160.0|  50.0|  28.7197777975515|
|    B|  女|  160.0|  50.0|28.732407566429345|
|    O|  女|  160.0|  50.0|28.726092681990423|
|   AB|  女|  160.0|  50.0| 28.71346291311255|
|    A|  男|  170.0|  35.0|36.194018649003766|
|    A|  男|  170.0| 100.0|28.835177589750728|
|    A|  女|  170.0|  35.0| 36.18913457728998|
|    A|  女|  170.0| 100.0| 28.83029351803694|
|    A|  男|  190.0|  80.0|  42.6417617554965|
|    A|  男|   17.0|   6.0|-48.82159525304273|
|    A|  男|17000.0|6500.0|  9017.13917142714|
+-----+---+-------+------+------------------+
```
##### 結果考察
* 男性/女性の結婚時期の違いは、うまいこと現れた。
* 血液型による違いが、ほとんど現れなかった。
* 肥満/標準/もやしの違いは、よくわからない。
* 男性高身長のルールはうまく反映されている。

ちなみに、南くんの恋人は生まれる50年前に結婚しており、巨神兵は結婚までに100世紀かかるらしい。突拍子もない結果に見えるが、`身長が高いほど結婚が遅い`というルールを線形的に捉えてくれているようにも見える。

### 決定木回帰モデルを作成して、予測値を得る

決定木はクラス分類が得意な手法なので、今回のような細かいルールの設定でも、うまく予測してくれるかもしれない。

解析手法を変わるとはいえ、インタフェースが変わるわけではないので、
大幅にコードを変える必要はなく、試行錯誤が楽。

#### クロス検証からモデルの作成まで
```scala
import org.apache.spark.ml.regression.DecisionTreeRegressor
import org.apache.spark.ml.Pipeline
import org.apache.spark.ml.evaluation.RegressionEvaluator
import org.apache.spark.ml.tuning.{
  ParamGridBuilder,
  CrossValidator
}

val regression = new DecisionTreeRegressor()
  .setLabelCol("marriedAge")
  .setFeaturesCol(scaler.getOutputCol)

val pipeline = new Pipeline()
  .setStages(Array(
    bloodIndexer,
    sexIndexer,
    assembler,
    scaler,
    regression
  ))

val paramGrid = new ParamGridBuilder()
  .addGrid(regression.maxBins, Array(2, 3, 4))
  .addGrid(regression.maxDepth, Array(10, 20, 30))
  .build()

val evaluator = new RegressionEvaluator()
  .setLabelCol(regression.getLabelCol)
  .setPredictionCol(regression.getPredictionCol)

val cross = new CrossValidator()
  .setEstimator(pipeline)
  .setEvaluator(evaluator)
  .setEstimatorParamMaps(paramGrid)
  .setNumFolds(3)

val model = cross.fit(training)
```
Regressorクラスの種類、paramGridで設定する項目が変わるぐらいで、その他は線形回帰のコードと変わらない。

##### 評価実行
```scala
model.transform(test)
  .select("blood", "sex", "height", "weight", "prediction").show
```
```
+-----+---+-------+------+------------------+
|blood|sex| height|weight|        prediction|
+-----+---+-------+------+------------------+
|    A|  男|  170.0|  65.0|41.666666666666664|
|    B|  男|  170.0|  65.0|22.857142857142858|
|    O|  男|  170.0|  65.0|              47.0|
|   AB|  男|  170.0|  65.0|19.666666666666668|
|    A|  女|  160.0|  50.0|              34.0|
|    B|  女|  160.0|  50.0|              20.0|
|    O|  女|  160.0|  50.0|              29.5|
|   AB|  女|  160.0|  50.0|              19.0|
|    A|  男|  170.0|  35.0|              35.0|
|    A|  男|  170.0| 100.0|41.666666666666664|
|    A|  女|  170.0|  35.0|              35.0|
|    A|  女|  170.0| 100.0|              41.0|
|    A|  男|  190.0|  80.0|              44.0|
|    A|  男|   17.0|   6.0|29.333333333333332|
|    A|  男|17000.0|6500.0|              44.0|
+-----+---+-------+------+------------------+
```

##### 結果考察
* どのルールも学習データの値に近い形で、うまいこと予測された。
* ただ、下２つの人外データに関しても、学習データに近い値が出てしまっているので、学習データの特徴値から大きくハズレるレコードの予測値は大味になってしまう？



### まとめ

今回は、CSV形式のサンプルデータを線形回帰と決定木回帰を用いて、値の予測を行った。

##### 線形回帰
細かいルールまでは予測しきれなかったが、学習データにない特徴を持つデータでも、うまく特徴を捉えようと、努力していた感があった。

##### 決定木回帰
細かいルールに基づいた値をうまく予測してくれていたが、学習データにない特徴を持つデータに関しては、諦めていた感があった。

分析手法によって、予測結果の傾向が変わることを確認できた。今後、ランダムフォレスト回帰、勾配ブースト木回帰、生存回帰など色々な手法も試してみたい。
