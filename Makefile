all:
	nasm -f bin src/snake.asm -o snake.bin

run: all
	qemu-system-i386 -drive format=raw,file=snake.bin

clean:
	rm -f snake.bin