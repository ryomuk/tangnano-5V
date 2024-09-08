PRG=ipl

.SUFFIXES: .asm .p .bin .lst

ROMFILE=rom.v
BIN=$(PRG).bin
PFILE=$(PRG).p
LFILE=$(PRG).lst

SRC=$(PRG).asm

# INCDIR=../include
#ASM=asl -L -i $(INCDIR)
ASM=asl -L

P2BIN=p2bin

all: $(PFILE) $(BIN) $(ROMFILE)

.asm.p:
	$(ASM) $<

.p.bin:
	$(P2BIN) $<

$(BIN): $(PFILE)

$(PFILE): $(SRC)

$(ROMFILE): $(BIN)
	./bin2v.pl $(BIN) > $(ROMFILE)

clean:
	rm $(BIN) $(PFILE) $(LFILE)
