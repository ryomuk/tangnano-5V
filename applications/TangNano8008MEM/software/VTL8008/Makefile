PRG=vtl

BIN=$(PRG).bin
PFILE=$(PRG).p
LFILE=$(PRG).lst
ROM=rom.v

SRC=$(PRG).asm user.asm

# INCDIR=../include
#ASM=asl -L -i $(INCDIR)
ASM=asl -L

P2BIN=p2bin
BIN2V=./bin2v.pl

.SUFFIXES: .asm .p .bin .lst

all: $(PFILE) $(BIN) $(ROM)

.asm.p:
	$(ASM) $<

.p.bin:
	$(P2BIN) $<

$(BIN): $(PFILE)

$(PFILE): $(SRC)

$(ROM): $(BIN)
	$(BIN2V) $(BIN) > $(ROM)

clean:
	rm $(BIN) $(PFILE) $(LFILE)
