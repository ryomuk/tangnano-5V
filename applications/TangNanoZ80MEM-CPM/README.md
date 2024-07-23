# TangNanoZ80MEM-CPM
- TangNanoZ80MEMにfloppy/hard diskエミュレータを追加してCP/Mを動作させる試みです．
- TangNano20Kのスロットに搭載したSDメモリカードを使用してfloppy/hard diskをエミュレートします．
- ハードウェアはTangNanoZ80MEMと同じものに，BUSREQ_n用のジャンパ線を1本追加します．

## floppy/hard disk エミュレータについて
- SDメモリはファイルシステム無しの生のままで使うのでddで読み書きします．
- SanDiskのsd(2GB)，KIOXIAのsdhc(32GB)，SAMSUNGのsdxc(64GB)での動作を確認しています．

## CP/Mについて
最初は
[udo-munk/z80pack](https://github.com/udo-munk/z80pack)のcpm22をそのまま使おうと思っていたのですが，コンソール入力がうまくいかなかったので，Universal Monitorで使っているコンソールのI/Oの仕様
```
data   = 00H; 
status = 01H;
 bit0: rx_data_ready
 bit2: tx_ready
```
にBIOSを書き変えたものを使いました．

## とりあえず動かすための手順
### ジャンパ配線
- DBG_TRG を BUSREQ_n に接続します．

### disk imageの準備
- 私はVMWare上のubuntuで作業しています．
- 書き込み先のsdメモリが/dev/sdb で正しいかちゃんと確認すること．間違えるとPCのディスクを破壊します.

```
- z80packを取ってくる．
git clone https://github.com/udo-munk/z80pack.git

- ビルドにはjpgとglの開発環境が必要っぽいので下記で追加．
sudo apt install libjpeg-dev
sudo apt install freeglut3-dev

- disksフォルダにcpm22用のdiskをコピーしておく
cd z80pack/cpmsim
rm -f disks/drive[ab].dsk
cp disks/library/cpm22-1.dsk disks/drivea.dsk
cp disks/library/cpm22-2.dsk disks/driveb.dsk

- bios-tangnano.patch をあててmakeする
cd srccpm2
patch -b < bios-tangnano.patch
make

- drivea.dsk を更新する
./putsys

- drivea.dskとdriveb.dskを継げてsd.dskを作る
dd if=/dev/zero of=sd.dsk bs=128 count=4096
dd if=../disks/drivea.dsk of=sd.dsk conv=notrunc bs=128 seek=0
dd if=../disks/driveb.dsk of=sd.dsk conv=notrunc bs=128 seek=2048

- sdメモリに書き込む(/dev/sdbで正しいかどうかは十分確認すること)
sudo if=sd.dsk of=/dev/sdb
```

## 関連情報，参考にしたサイト等
- z80pack [udo-munk/z80pack](https://github.com/udo-munk/z80pack)
- SuperMEZ80-CPM [hanyazou/SuperMEZ80-CPM](https://github.com/hanyazou/SuperMEZ80-CPM)
- CPUville [http://cpuville.com/Code/CPM.html](http://cpuville.com/Code/CPM.html)
- Universal Monitor [https://electrelic.com/electrelic/node/1317](https://electrelic.com/electrelic/node/1317)

## 更新履歴
- 2024/07/23: 初版公開
