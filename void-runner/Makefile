NAME = voidrunner

all: $(NAME).nes

$(NAME).o: main.asm
	ca65 main.asm -o $(NAME).o

$(NAME).nes: $(NAME).o $(NAME).cfg
	ld65 -C $(NAME).cfg $(NAME).o -o $(NAME).nes

clean:
	rm -f $(NAME).o $(NAME).nes

.PHONY: all clean
