#!/usr/bin/perl
use strict;
use warnings;

my $file = $ARGV[0];
open my $fh, "<", $file or die $!;
binmode($fh);

my $ROMSIZE = 0x8000;
my $buf;
my $data;

print
    "// rom.v\n".
    "// to be included from the top module at the comple\n\n".
    "initial\n".
    "begin\n";

for(my $addr = 0; $addr < $ROMSIZE; $addr++){
    if($addr % 4 == 0){
	printf "    ";
    }
    if(sysread($fh, $buf, 1)){
	$data = unpack("C", $buf);
    } else {
	if($addr % 4 != 0){
	    printf "\n";
	}
	last;
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
    
