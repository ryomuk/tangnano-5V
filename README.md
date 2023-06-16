# tangnano-5V
5V tolerant interface for Tang Nano 20K and 9K

This document is written mostly in Japanese. If necessary, please use a translation service such as DeepL (I recommend this) or Google.

## 概要
Tang Nano 20Kを5V系の回路に接続するためのインターフェースです．
(9K用は現在(2023/6/16)作成中．)


## 注意事項
- 回路の検証は済んでいますが，現時点(2023/6/16)で20K_rev1.1はまだ基板注文中なので，このガーバーで作成したボードそのものは未確認です．その前のバージョン(rev1.0)で寸法の間違いがあったりしたので，もしかしたらこの版も間違いがあるかもしれまえん．

## Tang Nano 20K 版(rev.1.1)
### BOM
|Reference          |Qty| Value          |Size |Memo |
|-------------------|---|----------------|-----|-----|
|C1, C2, C3, C4, C5 |5	|0.1uF	         |1608(mm)(0603(inch))| |
|J1, J2	            |2	|pin socket      |1x20 |for Tang Nano 20K|
|J3, J4             |2	|pin header      |1x20 |for 5V GPIO|
|U1, U2, U3, U4, U5 |5	|SN74CB3T3245PW  |TSSOP| |


### 画像
![](images/pcb.png)
![](images/3D_20k_1.png)
![](images/3D_20k_2.png)
![](images/3D_20k_3.png)

## 参考文献，データシート等
- [SN74CB3T3245 Data sheet](https://www.ti.com/lit/ds/symlink/sn74cb3t3245.pdf)
- [Application Note CBT-C, CB3T, and CB3Q Signal-Switch Families](https://www.ti.com/lit/an/scda008c/scda008c.pdf)
- [Logic Guide, Texas Instruments](https://www.ti.com/lit/sg/sdyu001ab/sdyu001ab.pdf)
- [ロジック・ガイド(日本語版), Texas Instruments](https://www.tij.co.jp/jp/lit/sg/jajt217/jajt217.pdf) Texas Instruments

## 更新履歴
- 2023/6/16: 初版公開 (Tang Nano 20K用)
