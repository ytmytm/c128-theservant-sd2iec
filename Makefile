
KICKASS := tools/KickAss.jar
JAVA := java
X128 := x128

KICKASSLAGS := 

SOURCES := servantpatch.asm

ROMS := servant.bin

X128FLAGS := -intfrom $(ROMS) -intfunc 1 -c128fullbanks

.PHONY: all clean test love

$(ROMS): $(SOURCES)
	$(JAVA) -jar $(KICKASS) $(SOURCES)

all: $(ROMS)

clean:
	-rm $(ROMS)

test:
	$(X128) $(X128FLAGS)

# a must!
love:
	@echo "Not war, eh?"

