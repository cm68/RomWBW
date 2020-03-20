TOOLS = ../../Tools
MOREDIFF := $(shell $(TOOLS)/unix/casefn.sh *.com Tunes/*)

include $(TOOLS)/Makefile.inc

all::
	mkdir -p Tunes

clean::
	rm -f $.COM *.com Tunes/*.pt? Tunes/*.mym

clobber::
	rm -f *.bin *.com *.img *.rom *.pdf *.log *.eeprom *.COM *.BIN Tunes/*.mym Tunes/*.pt?
