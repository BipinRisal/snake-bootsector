nasm -f bin src/snake.asm -o snake.bin
if ($LASTEXITCODE -eq 0) {
    qemu-system-i386 -drive format=raw,file=snake.bin
}