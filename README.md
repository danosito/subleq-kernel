# Public SUBLEQ kernel port (four-slot opt-in baseline)

This repository distributes **a source patch and an independent benign init source**, not a Linux tree, boot image, guest disk, or service kernel. It is **not corresponding source for any private service kernel**. The opt-in board interface expects four virtio-mmio slots in order: block 0, network 1, RNG 2, block 3; split read/write windows start at `0x60000000` / `0x61000000` with `0x1000` stride, pending bitmap at `0x62000000`, optional interruptible idle at `0x63000000`. Legacy ESI and ordinary QEMU do **not** implement this ABI. This port has no private syscall, challenge userspace, vulnerability modifications, service configuration, host runtime, or bundled disk/rootfs. A benign independent `/init` prints `PUBLIC_SUBLEQ_BASELINE_OK` and sleeps. The public port is not asserted equivalent to the service or to a service guest image; in particular it does not supply the machine implementation or service components. ESI Linux is NOMMU and does not provide a hardware isolation boundary between kernel and userspace.

## Pinned public upstream

- [ESI superproject `23d4d6c7c9f930fa72568ce795c9147af09d56ee`](https://github.com/adriancable/eternal/tree/23d4d6c7c9f930fa72568ce795c9147af09d56ee).
- [ESI Linux `c06286b9aa8a2245af9fbea92b12d812a77a9aa1`](https://github.com/adriancable/linux/tree/c06286b9aa8a2245af9fbea92b12d812a77a9aa1).
- [ESI LLVM/Clang/LLD `bb79724351cc201742c30aa4dbb9aaaa43be3654`](https://github.com/adriancable/llvm-project/tree/bb79724351cc201742c30aa4dbb9aaaa43be3654).
- [ESI uClibc-ng `073fbd989f5d9b2f4fd93f3da53820ae65cb7063`](https://github.com/adriancable/uclibc-ng/tree/073fbd989f5d9b2f4fd93f3da53820ae65cb7063).

The patch was generated from a *pristine public Linux commit* after source-auditing the independent pre-service virtio, IRQ, RNG, four-slot and idle changes and adapting their comments. No diff was generated from a challenge tree. Scope is limited to `arch/subleq/` and its config; no `drivers/` changes, syscall table changes or service-specific code. The IRQ change polls the pending bitmap on timer entry. Idle register use is configuration-gated; disable `CONFIG_SUBLEQ_IDLE_WAKEUP_V1` on any board without that register. Four-slot probing assumes all four slots exist; do not boot this configuration on the three-slot board. Kernel-facing four-slot support does not itself distribute a compatible machine implementation.

Linux kernel and patch: GPL-2.0, see `COPYING` and upstream per-file SPDX headers. Independent `rootfs/init.c`: 0BSD. The ESI superproject's MIT license does not supersede its separately GPL-licensed Linux submodule.

## Reproduce on Linux

Prerequisites: x86-64 or AArch64 Linux, Git, GCC, GNU make, Python 3, CMake, Ninja, flex, bison, bc, OpenSSL and libelf development headers, enough RAM/disk for a full LLVM build. System Clang does **not** contain the ESI Subleq target. Use no more than `-j2` on a shared/small builder.

1. Obtain the public [ESI source and build instructions](https://github.com/adriancable/eternal/blob/23d4d6c7c9f930fa72568ce795c9147af09d56ee/README.md): `git clone https://github.com/adriancable/eternal.git`; `git checkout 23d4d6c7c9f930fa72568ce795c9147af09d56ee`; `git submodule update --init --recursive`. Follow upstream Steps 1–4 to build ESI LLVM (`LLVM_EXPERIMENTAL_TARGETS_TO_BUILD=Subleq`, Clang/LLD and LLVM utilities), install public kernel headers, public uClibc-ng sysroot and runtime. **Do not use** upstream's packaged initramfs, BusyBox or capsule.
2. In this repo: `./scripts/prepare.sh /absolute/path/to/new-output` (must not exist). This clones the public pinned kernel and verifies `git apply --check` before application.
3. `./scripts/build.sh /absolute/path/to/new-output /absolute/path/to/public-eternal`. This builds the independent static `/init`, selects four-slot blk/net/rng/ext4 and idle configuration, verifies enabled Kconfig symbols, builds `vmlinux` with `-j2`, and generates a bootimage using the public ESI tool. The generated files stay in your chosen **external** output directory; do not upload them as service images.

The console-only [upstream VM](https://github.com/adriancable/eternal/blob/23d4d6c7c9f930fa72568ce795c9147af09d56ee/vm/vm_console.c) cannot validate a four-slot boot. A boot validation requires a separately obtained compatible public four-slot machine; no matching machine release is supplied here. A compile and config check do not establish device-runtime behavior or a boot-marker result.

## Verification

Verified on **Debian GNU/Linux 13 (trixie), x86-64**, using a fresh archive of the pinned *public* Linux commit and a prebuilt ESI Clang 22.1.0 SDK based on the pinned public LLVM source (the compiler binary itself was not rebuilt in this verification):

- `git apply --check port.patch && git apply port.patch`: success against pristine source.
- `clang -target subleq-unknown-linux --sysroot=PUBLIC_ESI_SYSROOT -isystem PUBLIC_ESI_UCLIBC_KERNEL_HEADERS -O2 -static -o rootfs/init init.c`: success; static init is `ELF32`, `Machine: Subleq`.
- `make ARCH=subleq CC=ESI_CLANG LD=ESI_LLD AR=ESI_AR NM=ESI_NM OBJCOPY=ESI_OBJCOPY defconfig`; `scripts/config --file .config --set-str INITRAMFS_SOURCE ROOTFS_LIST --set-str CMDLINE 'console=ttyS0 init=/init loglevel=5' -e VIRTIO_MENU -e VIRTIO_MMIO -e SUBLEQ_QEMU_VIRTIO -e SUBLEQ_QEMU_VIRTIO_RNG -e SUBLEQ_IDLE_WAKEUP_V1 -e HW_RANDOM -e HW_RANDOM_VIRTIO -e BLOCK -e BLK_DEV -e VIRTIO_BLK -e VIRTIO_NET -e EXT4_FS`; `make ARCH=subleq ... olddefconfig`: success; all eight kernel-feature symbols checked by `scripts/build.sh` resolved `=y`.
- `make -j2 ARCH=subleq CC=ESI_CLANG LD=ESI_LLD AR=ESI_AR NM=ESI_NM OBJCOPY=ESI_OBJCOPY vmlinux`: **exit 0**, 74 MiB ELF32 Subleq `vmlinux` (SHA-256 `4c2d64edf4b551d6c2fe064effdacbdc9e4fba9ffbc6193dd25b4c37825210ba`). The initramfs list contains only `/dev/console` and the independent static `/init`.
- Pinned ESI `tools/make_boot_image.py --llvm-bin ESI_LLVM_BIN --stack-size 536870912 --output OUTPUT vmlinux`: **exit 0**, 73 MiB bootimage. The image and compiler remain local and are **not** distributed here.

**Guest boot, four-slot device behavior and marker output have not been validated**: a compatible public four-slot QEMU machine is not shipped in this repo. Do not infer runtime correctness from build success.
