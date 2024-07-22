# UARTモジュールについて
- 各応用例の通信部分はSipeedのサンプル( https://github.com/sipeed/TangNano-20K-example )をベースにして独自に書き替えたものを使っています．CPU速度と通信速度によっては不安定だったりすることがあり，時々書き直してます．旧版との互換性を全部確認するのは面倒なので最新版は別のフォルダに入れることにしました．
- uart_txでステートが謎の遷移をする現象があったので，20240413版ではsipeedのサンプルを見倣ってステート遷移と信号の処理をバラバラに書くように修正したのですが，読み難いので20240507版で元に戻しました．が，20240413版より不安定かも．(2024/5/7)
- DCJ11用に修正したuart.vが前版より安定したのでapplications/uart/uart.v.20240621 に置きました．
- top.v側のrx_clearとtx_sendのロジックを下記のようにすると安定するようでした．
```
always @(受信バッファへのアクセストリガ or negedge rx_data_ready)
  if(~rx_data_ready)
     rx_clear <= 1'b0;
  else if(受信バッファへのアクセス判定)
     rx_clear <= 1'b1;
  else 
     rx_clear <= 1'b0;

always @(送信バッファへのアクセストリガ or negedge tx_ready)
  if(~tx_ready)
    tx_send <= 1'b0;
  else if(送信バッファへのアクセス判定)
    {tx_data, tx_send} <= {送信値, 1'b1};
  else
    tx_send <= 1'b0; // fail safe to avoid deadlock
```

## 更新履歴
- 2024/4/07: uart.vのバグ修正．(tx_ready関連)
- 2024/4/12: uart.vの最新版格納用のフォルダ applications/uart を作成
- 2024/4/13: applications/uart/uart.v 更新
- 2024/4/27: TangNanoZ80MEM: UARTの送信タイミング変更
- 2024/5/07: applications/uart/にuart.v.20240507 追加
- 2024/6/21: applications/uart/にuart.v.20240621 追加
- 2024/6/21: rx_clear, tx_sendのロジックについてこのREADMEに追記
