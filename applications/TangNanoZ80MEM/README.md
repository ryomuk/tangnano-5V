# TangNanoZ80MEM
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

## 関連ブログ
- [Z80をオーバークロックしてみる](https://blog.goo.ne.jp/tk-80/e/6de3708450bac79c2c1cef7728d0c877)
  
ASCIIART.BAS実行結果 (33MHz, Vcc=6.0V)
![](images/asciiart_33MHz_6V.jpg)

## 更新履歴
- 2023/06/25: 応用例にTangNanoZ80MEMを追加
- 2023/06/26: TangNanoZ80MEMのピン配置を変更．(rev1.0→rev.1.1)
- 2023/06/28: TangNanoZ80MEMの uart.vを更新．
- 2023/07/06: TangNanoZ80MEMを修正．27MHz(Vcc=5.0V), 33MHz(Vcc=6.0V)で動作．
- 2024/04/17: TangNanoZ80MEM: top.v修正(writeのバグ, RGBLED, UART_CTRL)
- 2024/04/17: TangNanoZ80MEM: rom/rom.unimon339.v 追加
- 2024/04/19: TangNanoZ80MEM: rom/bin2v.pl修正, romファイルの余計な0フィルを削除
- 2024/04/27: TangNanoZ80MEM: UARTの送信タイミング変更

