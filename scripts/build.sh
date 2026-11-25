#!/usr/bin/env bash
# Requires PUBLIC ESI checkout and its separately built LLVM/uClibc sysroot.
# Usage: build.sh PREPARED_OUTPUT PUBLIC_ESI_CHECKOUT
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$(cd "${1:?usage: build.sh PREPARED_OUTPUT PUBLIC_ESI_CHECKOUT}" && pwd)
ESI=$(cd "${2:?usage: build.sh PREPARED_OUTPUT PUBLIC_ESI_CHECKOUT}" && pwd)
[[ $(git -C "$ESI" rev-parse HEAD) == 23d4d6c7c9f930fa72568ce795c9147af09d56ee ]] || {
    echo 'Public ESI checkout at required revision is needed' >&2; exit 1;
}
[[ $(git -C "$ESI/llvm-project" rev-parse HEAD) == bb79724351cc201742c30aa4dbb9aaaa43be3654 ]]
[[ $(git -C "$OUT/linux" rev-parse HEAD) == c06286b9aa8a2245af9fbea92b12d812a77a9aa1 ]]
for binary in clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-readelf; do
    test -x "$ESI/llvm-project/build/bin/$binary" || { echo "Missing ESI $binary" >&2; exit 1; }
done
# The independent init links statically; never embed ESI's bundled rootfs.
"$ESI/tools/clang_userspace.sh" "$ROOT/rootfs/init.c" "$OUT/rootfs/init" -static
chmod 755 "$OUT/rootfs/init"
# gen_init_cpio list gives PID 1 a console without needing root privileges.
printf 'dir /dev 0755 0 0\nnod /dev/console 0600 0 0 c 5 1\nfile /init %s 0755 0 0\n' \
    "$OUT/rootfs/init" > "$OUT/rootfs.list"
L="$OUT/linux"
T="$ESI/llvm-project/build/bin"
args=(ARCH=subleq CC="$T/clang" LD="$T/ld.lld" AR="$T/llvm-ar" NM="$T/llvm-nm" OBJCOPY="$T/llvm-objcopy")
make -C "$L" "${args[@]}" defconfig
"$L/scripts/config" --file "$L/.config" --set-str INITRAMFS_SOURCE "$OUT/rootfs.list" \
    --set-str CMDLINE 'console=ttyS0 init=/init loglevel=5' \
    -e VIRTIO_MENU -e VIRTIO_MMIO -e SUBLEQ_QEMU_VIRTIO \
    -e SUBLEQ_QEMU_VIRTIO_RNG -e SUBLEQ_IDLE_WAKEUP_V1 \
    -e HW_RANDOM -e HW_RANDOM_VIRTIO -e BLOCK -e BLK_DEV \
    -e VIRTIO_BLK -e VIRTIO_NET -e EXT4_FS
make -C "$L" "${args[@]}" olddefconfig
for option in SUBLEQ_QEMU_VIRTIO SUBLEQ_QEMU_VIRTIO_RNG SUBLEQ_IDLE_WAKEUP_V1 VIRTIO_MMIO VIRTIO_BLK VIRTIO_NET HW_RANDOM_VIRTIO EXT4_FS; do
    grep -qx "CONFIG_${option}=y" "$L/.config" || { echo "Missing CONFIG_$option" >&2; exit 1; }
done
make -C "$L" -j2 "${args[@]}" vmlinux
python3 "$ESI/tools/make_boot_image.py" --llvm-bin "$T" --stack-size 536870912 \
    --output "$OUT/vmlinux.bootimage" "$L/vmlinux"
printf 'Built independent initramfs into %s (never distribute this image as private-kernel source)\n' "$OUT/vmlinux.bootimage"
