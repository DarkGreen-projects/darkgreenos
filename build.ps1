# DarkgreenOS - build script (MSYS2 / WSL recommended)
# Install: pacman -S nasm mingw-w64-i686-binutils grub qemu (MSYS2)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$Build = Join-Path $Root "build"
$IsoDir = Join-Path $Root "iso\boot\grub"

New-Item -ItemType Directory -Force -Path $Build, $IsoDir | Out-Null

$AsmFiles = @(
    "boot", "kernel", "gdt", "idt", "io", "vga", "keyboard", "pit",
    "paging", "pagefault", "serial", "companion",
    "multiboot_parse", "osview", "brain", "mem_safe"
)

foreach ($name in $AsmFiles) {
    nasm -f elf32 -I "$Root\src\" -o "$Build\$name.o" "$Root\src\$name.asm"
}

$Ld = Get-Command i686-elf-ld -ErrorAction SilentlyContinue
if (-not $Ld) { $Ld = Get-Command ld -ErrorAction SilentlyContinue }
if (-not $Ld) { throw "Linker not found. Install i686-elf-binutils or MSYS2 ld." }

& $Ld.Source -m elf_i386 -T "$Root\linker.ld" -o "$Build\darkgreenos.kernel" @(
    $AsmFiles | ForEach-Object { "$Build\$_.o" }
)

Copy-Item "$Build\darkgreenos.kernel" "$Root\iso\boot\darkgreenos.kernel" -Force
Copy-Item "$Root\grub.cfg" "$IsoDir\grub.cfg" -Force

Write-Host "Kernel: $Build\darkgreenos.kernel"
Write-Host "Run 'grub-mkrescue -o build/darkgreenos.iso iso' then qemu-system-i386 -cdrom build/darkgreenos.iso"
