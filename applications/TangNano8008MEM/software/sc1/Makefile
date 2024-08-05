PRG=sc1

.SUFFIXES: .asm .p .bin .lst

BIN=$(PRG).bin
PFILE=$(PRG).p
LFILE=$(PRG).lst

SRC=$(PRG).asm user.asm

# INCDIR=../include
#ASM=asl -L -i $(INCDIR)
ASM=asl -L

P2BIN=p2bin

all: $(PFILE) $(BIN)

.asm.p:
	$(ASM) $<

.p.bin:
	$(P2BIN) $<

$(BIN): $(PFILE)

$(PFILE): $(SRC)

clean:
	rm $(BIN) $(PFILE) $(LFILE)
