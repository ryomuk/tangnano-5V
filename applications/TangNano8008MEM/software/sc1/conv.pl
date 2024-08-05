#!/usr/bin/perl

# This Perl script is for converting
# sc1.asm written for AS8 8008 assembler
# https://www.willegal.net/scelbi/software/sc1.asm
# to the assembler code for The Macroassembler AS (asl)
# http://john.ccac.rwth-aachen.de:8000/as/
#
# Usage:
# cp sc1.asm sc1.asm.org
# ./conv.pl < sc1.asm.org > sc1.asm


$line = 0;
while(<>){
    $line++;
    if($line == 51){
	print "\t cpu 8008\n\n".
	    "LB	function x, ((x)&255)\n".
	    "HB	function x, (((x)>>8)&255)\n\n".
	    "\torg 0H\n".
	    "\tNOP\n".
	    "\tJMP EXEC\n\n"
	    ;
	next;
    }
    if($line == 80){
	printf "\n\tinclude \"user.asm\"\n";
	next;
    }
    if($line >= 81 && $line <=152){
	printf ";$_";
	next;
    }
    if(m/^;/){
	print;
	next;
    }
    if(m/DATA 224,215,212	; CTRL-T, CARRIAGE RETURN, LINE FEED/){
	printf ";$_";
 	print "\tDB 215Q,215Q,212Q\t; CARRIAGE RETURN, CARRIAGE RETURN, LINE FEED\n";
	next;
    }

    s/"SCR$/"SCR"/g;
    if(m/(\s+DATA\s+)"(.*)"(.*)/){
	$str = $2;
	$comment = $3;
	foreach $c (split //, $str){
	    print "\tDB '$c'+200Q$comment\n";
	    $comment = "";
	}
    }
    elsif(m/(.*\D)(\d\d\d)#(\d\d\d)(.*)/){
	$a = $1;
	$b = oct($2);
	$c = oct($3);
	$d = $4;
	printf "%s %04XH%s\n", $a, $b*256+$c, $d;
    } elsif(m/(\s+)DATA(\s+)\*(\d+)(.*)/){
	printf "$1DS$2$3$4\n";
    } else {
	s/(\d\d\d)(\s+)/$1Q$2/g;
	s/(\d\d\d),/$1Q,/g;
	s/(\d\d\d)$/$1Q\n/g;
	s/\\HB\\(\S+)/HB($1)/g;

	if(m/(\s+)DATA (.*)/){
	    print "$1DB $2\n";
	} else {
	    print;
	}
    }
}
    
