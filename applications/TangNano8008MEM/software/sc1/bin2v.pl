#!/usr/bin/perl
use strict;
use warnings;

my $file = $ARGV[0];
open my $fh, "<", $file or die $!;
binmode($fh);

my $MAXROMSIZE = 0x4000;
my $buf;
my $data;
my $last = 0;

print
    "// rom.v\n".
    "// to be included from the top module at the compile\n\n".
    "initial\n".
    "begin\n";

for(my $addr = 0; $addr < $MAXROMSIZE; $addr++){
    if($addr % 4 == 0){
	printf "    ";
    }
    if(sysread($fh, $buf, 1)){
	$data = unpack("C", $buf);
    } else {
	$data = 0;
	$last = 1;
    }
    printf("mem['h%04X]=8'h%02X;", $addr, $data);
    if($addr % 4 == 3){
	printf "\n";
	last if($last);
    } else {
	printf " ";
    }
}
print  "end\n";

close $fh;
    
