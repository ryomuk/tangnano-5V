#!/usr/bin/perl
use strict;
use warnings;

my $file = $ARGV[0];
open my $fh, "<", $file or die $!;
binmode($fh);

my $ROMSTART = 0x0000;
my $ROMSIZE  = 0x1000;
my $ROMEND   = $ROMSTART + $ROMSIZE;
my $buf;
my $data;

print
    "// rom.v\n".
    "// to be included from the top module at the comple\n\n".
    "initial\n".
    "begin\n";


for(my $addr = $ROMSTART; $addr < $ROMEND ; $addr++){
    if($addr % 4 == 0){
	printf "    ";
    }
    if(sysread($fh, $buf, 1)){
	$data = unpack("C", $buf);
    } else {
	$data = 0;
    }
    printf("mem['h%04X]=8'h%02X;", $addr, $data);
    if($addr % 4 == 3){
	printf "\n";
    } else {
	printf " ";
    }
}
print  "end\n";

close $fh;
    
