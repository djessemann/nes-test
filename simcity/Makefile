NAME = micropolis

all: $(NAME).nes

chr.bin: tools/gfx.py tools/gfx_tiles.py
	python3 tools/gfx.py chr.bin

$(NAME).o: src/*.asm chr.bin
	ca65 src/main.asm -o $(NAME).o

$(NAME).nes: $(NAME).o simcity.cfg
	ld65 -C simcity.cfg $(NAME).o -o $(NAME).nes

test: $(NAME).nes
	python3 tools/nesemu.py $(NAME).nes --frames 120 --png /tmp/boot.png

clean:
	rm -f $(NAME).o $(NAME).nes chr.bin

.PHONY: all clean test
