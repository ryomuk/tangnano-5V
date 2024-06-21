# tangnano-5V
5V tolerant interface for Tang Nano 20K and 9K

This document is written mostly in Japanese. If necessary, please use a translation service such as DeepL (I recommend this) or Google.

# 概要
Tang Nanoを5V系の回路に接続するためのインターフェースです．昔のCPU用のメモリシステムやI/OをTang Nanoに実装することを主目的に作成しました。
Tang Nano 20K用と9K用の2種類があります．

# Tang Nano 20K 版(rev.1.1a)
## 機能
- Tang Nanoの20KのGPIO(全34本)を，SN74CB3T3245(レベルシフタ搭載バススイッチ)を介して5V系(TTL, CMOS)に接続します．
- バッファではなくスイッチで行なっているため，特に信号方向を意識することなく双方向接続が可能，信号の伝達遅延は0.25ns以下です．

## 原理
- 5V→3.3VはSN74CB3T3245によって5V系から3.3V系にレベル変換されます．
- 3.3V→5Vはレベル変換は行なわれず，3.3V系の信号が出力されますが，5VTTLの閾値は1.5V，5VCMOSの閾値は2.5Vなので問題無いということのようです．

## 動作の確認状況
- 27MHzのシステムクロックが全GPIOで5V系に出力できることを確認しました．(75番ピンについては下記参照)
- 5V系→3.3V系: 5Vの入力信号に対し，出力が3.3Vになることを確認しました．
- 3.3V系→5V系: 3.3Vの入力信号に対し，出力が3.3Vになることを確認しました．
- データシートによると遅延はmax 0.25nsで，手元のオシロでは測定限界以下でした．

## Tang Nano 20Kの75番ピンについて
- Tang Nano 20K(v3921)の75番ピンは，C51(100nF)でGNDに接続されているため，そのままだと低速(数十KHz)でしか動作しません．他のピンと同様に使用するためにはC51を外す必要があります．低速動作で構わないのであれば気にしなくていいです．
- 最新の回路図v3921(Date:2023-07-11, ファイルの日付2023-11-08)ではC51がNCになっているようです。2024年3月に購入したものがC51未実装だったという情報がありました。(2024/4/15)
- R22(10K)でGNDにプルダウンされているので、外部でプルアップすると誤動作の原因になります。

### 75番ピン以外に関するメモ
TangNano20K、pin75以外にも若干癖のあるpinがあるのでメモしておきます。
- pin15～20は510RでLEDに継がっていて入力に使うとIIL=約3.0mA。
- pin52～53は2.2Kで5VとFETに継がっててIIL=約4.4mA。
- pin26は5.1KでGND、IIH=0.6mA。
- その他のほとんどのピンはだいたいIIL=0.9mA程度、IIH=0.1mA以下。

## BOM
|Reference          |Qty| Value          |Size |Memo |
|-------------------|---|----------------|-----|-----|
|C1, C2, C3, C4, C5 |5	|0.1uF	         |1608(mm)(0603(inch))| |
|J1, J2	            |2	|pin socket      |1x20 |for Tang Nano 20K|
|J3, J4             |2	|pin header      |1x20 |for 5V GPIO|
|U1, U2, U3, U4, U5 |5	|SN74CB3T3245PW  |TSSOP| |

## 画像
![](images/tn20k5v_rev1_1a.jpg)
![](images/pcb.png)
![](images/3D_20k_1.png)
![](images/3D_20k_2.png)
![](images/3D_20k_3.png)

# 応用例
- いろいろなCPUのメモリシステム，UARTを構築した応用例です．CPUをFPGAでエミュレートするのではなく、本物のCPUを動かすことを目的にしています。
- 勉強のために作った習作なのでかなり荒削りでいろいろと不備やバグがあると思いますがご容赦下さい。
- 各CPUで共通に使用しているUARTモジュールuart.vは適当に作ったために時々不具合が見つかってバグ修正しています．旧版との互換性は確認していないので，CPUによっては旧版のままになっています．最新版は別フォルダ [applications/uart/uart.v](applications/uart/uart.v) に置いてありますので，必要であればコピーしてご使用下さい．
- ターミナルソフトの通信遅延はCPUの速度や通信速度にあわせて適宜設定して下さい。(例: 10ms/文字, 100ms/行)

## TangNanoZ80MEM [applications/TangNanoZ80MEM](applications/TangNanoZ80MEM)
- Z80用のメモリシステムとクロック，UARTです．
- クロックはTTLレベルではなくHでVcc-0.6Vのレベルが必要なので外付けのICで引き上げています．4MHz程度であれば330Ωプルアップ抵抗だけでも動きました．
- Z84C0020，ブレッドボードで20.25MHzで動作しました．
- Z80のVccをTangNano側のVCC(USB給電)と別にしたいこともあるかもしれないので，ピンヘッダで接続するようにしています．
- DBG_TRGとLED_RGBはデバッグ用の信号です．
- 75番ピンはRESET_nに割り当てたのでC51を外さなくても動作します．
- PCB版で27MHz(USB給電，Vcc=4.94V), 33MHz(Z80はTangNanoと別給電, Vcc=6.0V)で動作しました．(2023/7/6)
- uart.vにバグがあったので修正しました．(2024/4/7)
- top.vのデフォルトのクロック周波数を13.5MHzにしました．(2024/4/7)
- uart.vをリファクタリングしました．(2024/4/13)
- top.v: write_memoryのエッジの正負が間違っていたので修正しました．(2024/4/17)
- top.v: RGBLEDで点滅とUARTの状態表示をするようにしました．(2024/4/17)
- top.v: UART_CTRLのrx_data_readyの位置をbit1から0に変更しました．(2024/4/17)
- rom/rom.unimon339.v を同梱しました．ライセンスはファイル参照．(2024/4/17)
- top.v: tx_send関連のタイミングを修正しました．(2024/4/27)

### 関連ブログ
- [Z80をオーバークロックしてみる](https://blog.goo.ne.jp/tk-80/e/6de3708450bac79c2c1cef7728d0c877)
  
ASCIIART.BAS実行結果 (33MHz, Vcc=6.0V)
![](images/asciiart_33MHz_6V.jpg)

## TangNano6809MEM [applications/TangNano6809MEM](applications/TangNano6809MEM)
- MC6809用のメモリシステムとクロック，UARTです．
- [電脳伝説さんのSBC6809](https://vintagechips.wordpress.com/2017/12/05/sbc6809%E3%83%AB%E3%83%BC%E3%82%BA%E3%82%AD%E3%83%83%E3%83%88/)のdatapackに入っているBASIC9がバイナリそのままで動きます．

BASIC9起動画面
![](images/6809_basic.png)

ASCIIART.BAS実行結果 (外部クロック6MHz)
![](images/6809_asciiart.png)

### 注意事項(TangNano6809MEM)
- PC接続時にUSB経由の通信が確立しない問題があることがわかりました．
- ~~入力に使用しているピンのどれかがUSB-JTAGの初期化用の信号と競合しているのが原因な気がしますが特定できませんでした．~~
- ~~下記のようにVCCのラインを切断して，PCと接続後に6809のVCCを継げるという手順が必要です．~~
 ~~images/6809_vcc.jpg~~
- RESET_n(pin75)のプルアップ抵抗(R1)が原因でした。pin75は内部で10KでプルダウンされていてB616_BOOTに継がっており、それと競合していました。
- R1を外すことにより上記問題は解決します。

## TangNano8070MEM [applications/TangNano8070MEM](applications/TangNano8070MEM)
- INS8070N(SC/MP III)のメモリシステム，クロック，UARTです．
- [ElectrelicさんのUniversal Monitor](https://electrelic.com/electrelic/node/1317)が，UARTのハンドシェイク部分を微修正して動きました．

ブレッドボード版
![](images/tangnano8070mem.jpg)

## TangNanoDCJ11MEM [ryomuk/TangNanoDCJ11MEM](https://github.com/ryomuk/TangNanoDCJ11MEM)
![](images/DCJ11MEM.jpg)
- DEC DCJ11 (PDP-11の命令セットを持つCPU)のメモリシステムとUARTです。
- 詳細は別リポジトリ[TangNanoDCJ11MEM](https://github.com/ryomuk/TangNanoDCJ11MEM) にあります。

# Tang Nano 9K 版(rev.3.0)
## rev2.0からの差分
- rev2.0(全バンクでTXS0108Eを使用)では、Pin68～75(HDMI用ピン)への入力で異常発振したり、USB接続が出来無くなったりする問題が発生していましたが、3.3Vバンクを20K版と同じ74CB3T3245に変更したところそれらの問題が解消しました。
  
## 機能
- Tang Nanoの9KのGPIO(全45本)を5V系(TTL, CMOS)に接続します．
- 信号方向を意識することなく双方向接続が可能です．
- Pin79〜86は1.8Vのバンク(BANK3)なのでTXS0108Eを用いて，1.8V←→(5V or 3.3V)の変換をします．その他のピンはCB3T3245を用いて3.3V←5V, 3.3V→3.3Vです．

## 動作の確認状況
- 27MHzのシステムクロックが全GPIOで5V系に出力できることを確認しました．
- 入力は単体試験(1ピンづつ)では期待通りの動きをしますが，入出力混在時に怪しい挙動を示しました．

### 見つかった問題点
- (pin63 & pin86) をそれ以外の全ピンに出力するというテストで出力がおかしくなることがある．おそらくBANK3(1.8V系)がなんらかの干渉をしている．
- pin68〜75は入出力とも若干歪む．

### 問題点を回避するためのガイドライン
- BANK3(1.8V系)は出力専用にする．
- HDMI用のピンは歪むので動作を確認しながら使う．

## BOM
|Reference            |Qty| Value          |Size |Memo |
|---------------------|---|----------------|-----|-----|
|C3,C4,C5,C6,C7,C8,C9 |7  |0.1uF	   |1608(mm)(0603(inch))|C1,C2は無し |
|J1                   |1  |pin header      |1x3 |BANK3 HI側の電圧選択用|
|J2,J3                |2  |pin socket      |1x24 |for TangNano9K|
|J4,J5                |2  |pin header      |1x24 |for 5V GPIO|
|PS1                  |1  |TLV71318        |SOT23-5| 1.8Vレギュレータ|
|U1                   |1  |TXS0108EPW      |TSSOP| |
|U2,U3,U4,U5,U6       |5  |SN74CB3T3245PW  |TSSOP| |

- C1,C2は.1.8Vレギュレータ用でしたが不要なので消した後にアノテーションし直すのを忘れて欠番になっています．

## 画像
![](images/tn9k5v_rev3.jpg)

## 応用例
## TangNanoZ80MEM [applications/TangNanoZ80MEM_9K](applications/TangNanoZ80MEM_9K)
![](images/tangnanoz80mem9k.jpg)
- 9K用インターフェースの動作確認用にブレッドボードで組んでみました．
- ~~とりあえず4.5MHzならたいていのピン配置で動きました．今のところ13.5MHzが限界．20K版ほど高速には動作しませんでした．~~
- ~~HDMIのコンデンサを外したら余計に動作しなくなったり，ピンアサインを変えるだけで動作しなくなったりするのでどこかにタイミング的な問題がありそうです．~~
- ~~MREQ_nはHDMIピンに継げた方が安定するので，MREQ_nでアドレスをラッチしているあたりが怪しそう．~~
- メモリライトのタイミングをWR_nではなくCLKでトリガーするようにしたら27MHzでも動くようになりました。ただし、HDMI端子のコンデンサ除去必須です。

# その他
## UARTモジュールについて [applications/uart/uart.v](applications/uart/)
- 各応用例の通信部分はSipeedのサンプル( https://github.com/sipeed/TangNano-20K-example )をベースにして独自に書き替えたものを使っています．CPU速度と通信速度によっては不安定だったりすることがあり，時々書き直してます．旧版との互換性を全部確認するのは面倒なので最新版は別のフォルダに入れることにしました．
- uart_txでステートが謎の遷移をする現象があったので，20240413版ではsipeedのサンプルを見倣ってステート遷移と信号の処理をバラバラに書くように修正したのですが，読み難いので20240507版で元に戻しました．が，20240413版より不安定かも．(2024/5/7)
- DCJ11用に修正したuart.vが前版より安定したのでapplications/uart/uart.v.20240621 に置きました．
- top.v側のrx_clearのロジックを下記のようにすると安定するようでした．
```
always @(受信バッファへのアクセストリガ or negedge rx_data_ready)
  if(~rx_data_ready)
     rx_clear <= 1'b0;
  else if(受信バッファへのアクセス判定)
     rx_clear <= 1'b1;
  else 
     rx_clear <= 1'b0;
```

## 参考文献，データシート等
- [SN74CB3T3245 Data sheet](https://www.ti.com/lit/ds/symlink/sn74cb3t3245.pdf)
- [Application Note CBT-C, CB3T, and CB3Q Signal-Switch Families](https://www.ti.com/lit/an/scda008c/scda008c.pdf)
- [Logic Guide, Texas Instruments](https://www.ti.com/lit/sg/sdyu001ab/sdyu001ab.pdf)
- [ロジック・ガイド(日本語版), Texas Instruments](https://www.tij.co.jp/jp/lit/sg/jajt217/jajt217.pdf)
- [5V系・3.3V系信号レベル変換, cepstrum](https://www.cepstrum.co.jp/hobby/5v33v/5v33v.html)

## 更新履歴
- 2023/6/16: 初版公開 (Tang Nano 20K用 rev.1.1)
- 2023/6/25: 応用例にTangNanoZ80MEMを追加
- 2023/6/26: TangNanoZ80MEMのピン配置を変更．(rev1.0→rev.1.1)
- 2023/6/28: TangNanoZ80MEMの uart.vを更新．
- 2023/7/06: TangNanoZ80MEMを修正．27MHz(Vcc=5.0V), 33MHz(Vcc=6.0V)で動作．
- 2023/7/11: Tang Nano 20K用 rev.1.1→rev.1.1a (差分はシルクの修正のみ)
- 2023/7/11: Tang Nano 9K用 rev.2.0公開 (若干問題あり)
- 2023/7/15: README.md用の画像を1.1aにアップデート
- 2023/7/19: 応用例にTangNano6809MEMを追加
- 2023/7/20: tn20k5v rev1.1aの実物作成，動作確認OK．写真掲載．
- 2023/7/23: 応用例にTangNano8070MEMを追加．
- 2024/4/07: uart.vのバグ修正．(tx_ready関連)
- 2024/4/11: TangNano6809MEMに関する注意事項記載
- 2024/4/12: uart.vの最新版格納用のフォルダ applications/uart を作成
- 2024/4/13: applications/uart/uart.v 更新
- 2024/4/14: README修正(応用例に関するエクスキューズを追記)
- 2024/4/15: README修正(6809、R1の除去について, TangNano20Kのピンに関するメモ)
- 2024/4/17: TangNanoZ80MEM: top.v修正(writeのバグ, RGBLED, UART_CTRL)
- 2024/4/17: TangNanoZ80MEM: rom/rom.unimon339.v 追加
- 2024/4/19: TangNanoZ80MEM: rom/bin2v.pl修正, romファイルの余計な0フィルを削除
- 2024/4/21: Tang Nano 9K用 rev.3.0公開
- 2024/4/27: TangNanoZ80MEM: UARTの送信タイミング変更
- 2024/5/07: applications/uart/にuart.v.20240507 追加
- 2024/6/21: applications/uart/にuart.v.20240621 追加
