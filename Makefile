# DarkgreenOS build
# Use WSL or MSYS2 on Windows:  wsl make iso
# Windows CMD without WSL: install NASM + MSYS2, then adjust LD below.

ASM       ?= nasm
ASMFLAGS  = -f elf32 -I src/
ASM64FLAGS = -f elf64 -I src/

# Prefer i686 cross-ld; fall back to system ld with elf_i386 (Ubuntu: gcc-multilib)
LD        := $(shell command -v i686-elf-ld 2>/dev/null || command -v i686-linux-gnu-ld 2>/dev/null || echo ld)
LDFLAGS   = -m elf_i386 -T linker.ld

SRC_ASM   = src/boot.asm src/kernel.asm src/gdt.asm src/idt.asm \
            src/io.asm src/vga.asm src/keyboard.asm src/pit.asm \
            src/paging.asm src/pagefault.asm src/gpfault.asm src/invalidop.asm src/serial.asm src/companion.asm \
            src/multiboot_parse.asm src/mb2_parse.asm src/framebuffer.asm src/font8.asm \
            src/gfx.asm src/mouse.asm src/gui.asm src/sysres.asm \
            src/osview.asm src/brain.asm src/tinylm.asm src/pmm.asm \
            src/rmgr.asm src/rmgr_profile.asm src/rmgr_audit.asm src/rmgr_hook.asm \
            src/darkmind.asm src/dmem.asm src/pmm_alloc.asm src/mem_safe.asm
OBJ       = $(SRC_ASM:src/%.asm=build/%.o)

KERNEL    = build/darkgreenos.kernel
ISO       = build/darkgreenos.iso
MEMORY    = model/darkmind-memory.bin
QEMU_MEM  ?= 2048
QEMU      ?= qemu-system-x86_64
# Default: no -serial stdio (avoids QEMU iothread mutex abort on long I/O bursts).
# Use: make run-serial  for COM1 on stdio (companion / profile export).
# grab-on=hover needs newer QEMU; click inside the GTK window to capture keyboard
QEMU_OPTS = -cdrom $(ISO) -m $(QEMU_MEM) -display gtk -k it

.PHONY: all clean run iso dirs check-tools verify-mb2

verify-mb2: $(KERNEL)
	python3 scripts/mb2_checksum.py $(KERNEL)

all: check-tools dirs $(MEMORY) $(KERNEL)

check-tools:
	@command -v $(ASM) >/dev/null 2>&1 || ( \
		echo ""; \
		echo "ERROR: '$(ASM)' not found."; \
		echo "  Windows: open WSL and run:"; \
		echo "    bash scripts/setup-wsl.sh"; \
		echo "    cd /mnt/c/Users/feded/darkgreenos && make"; \
		echo "  Or install MSYS2: pacman -S nasm mingw-w64-i686-binutils"; \
		echo ""; \
		exit 127 \
	)
	@command -v $(LD) >/dev/null 2>&1 || ( \
		echo "ERROR: linker '$(LD)' not found. Try: sudo apt install gcc-multilib"; \
		exit 127 \
	)

dirs:
	@mkdir -p build iso/boot/grub iso/boot/model iso/boot/memory

build/%.o: src/%.asm
	$(ASM) $(ASMFLAGS) -o $@ $<

$(KERNEL): $(OBJ) linker.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJ)

$(MEMORY): scripts/build_darkmind_memory.py
	python3 scripts/build_darkmind_memory.py

iso: all
	cp $(KERNEL) iso/boot/darkgreenos.kernel
	cp $(MEMORY) iso/boot/memory/darkmind-memory.bin
	cp grub.cfg iso/boot/grub/grub.cfg
	grub-mkrescue -o $(ISO) iso 2>/dev/null || \
		grub-mkrescue -o $(ISO) iso -- -quiet

run: iso
	$(QEMU) $(QEMU_OPTS)

run-serial: iso
	$(QEMU) -cdrom $(ISO) -m $(QEMU_MEM) -serial stdio -display gtk

# Companion AI agent: serial on TCP 4444 (use with tools/companion_agent.py)
run-ai: iso
	$(QEMU) -cdrom $(ISO) -m $(QEMU_MEM) -serial tcp:127.0.0.1:4444,server,nowait

clean:
	rm -rf build iso
