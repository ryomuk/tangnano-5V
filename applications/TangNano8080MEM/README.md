# TangNano8080MEM
![](../../images/tangnano8080mem.jpg)
## 概要
- Intel 8080用のメモリシステム，クロック，UART，diskエミュレータです．
- CP/Mが動きます．

## PCB rev.1.1
- 回路図，ガーバーファイル等は[hardware/rev.1.1](hardware/rev.1.1/)にあります．
### BOM
|Reference          |Qty| Value          |Memo |
|-------------------|---|----------------|-----|
|C1                 |1  |2.2uF           |     |
|C2,C6              |2  |1uF             |     |
|C3,C4              |2  |10uF            |     |
|C5,C7,C8           |3  |0.1uF           |     |
|D1,D2              |2  | LED            |任意     |
|J1                 |1  | DIP-40 Socket or 20x1 Pin frame x2  |TangNano5V用|
|J2,J3              |2  |Conn_01x20      |任意(観測用)|
|PS1                |1  |MAU104          |5V→12V用DCDC,  https://akizukidenshi.com/catalog/g/g104132/ |
|PS2                |1  |TJ7660          |5V→-5V用, https://akizukidenshi.com/catalog/g/g112017/|
|R1                 |1  | 10k             |     |
|R2,R3              |2  | 1k〜100k(適宜)     | 値はLEDにあわせて任意|
|R4,R5              |2  | 47     | クロック用ダンピング抵抗|
|RN1                |1  | 4.7k x8       |データバスプルアップ     |
|RN2                |1  | 100k x4       |制御信号プルアップ       |
|U1                 |1  | MIC4427 |  クロックドライバ|
|U2                 |1  | 40pin ZIFソケット |  8080用|

- RN2は当初10KΩにしていたのですが，TangNano20Kのpin75はB616_BOOTに継がっていて，起動時にUSBを検出してくれなくなってしまうので100kΩに変更しました．[TangNano6809MEM](../TangNano6809MEM)で起きていたのと同様の問題でした．

## FPGAに実装したもの
- プロジェクトは[TangNano8080MEM_project](TangNano8080MEM_project)です．
- [TangNanoZ80MEM-CPM](../TangNanoZ80MEM-CPM/)をベースにして，2相クロック，8228相当の制御信号の変換を追加しました．

## 起動方法
- [TangNanoZ80-CPM](../TangNanoZ80MEM-CPM/)と同じ手順で作成したdiskイメージで起動できます．

## 更新履歴
- 2024/09/08: 初版公開

