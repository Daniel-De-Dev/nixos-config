# Secure Boot, Lockdown, and Encrypted Hibernation

```nix
my.host.security.kernelLockdown = "integrity";
my.hardware.hibernation = {
  enable = true;
  lockdownOverride.enable = true;
  # Existing resumeDevice and resumeOffset remain host-specific.
};
```

`kernelLockdown` accepts `"none"` (the default), `"integrity"`, or
`"confidentiality"`. `strictKernel` independently retains the allocator, memory,
and DMA hardening parameters. The LSM list extends `security.lsm`, allowing NixOS
to generate one `lsm=` parameter with its required AppArmor-before-BPF ordering.

## The Security Tradeoff

The exception permits an unauthenticated resume image under lockdown. It does
not make ordinary hibernation satisfy lockdown's original security guarantee.

The patch bypasses only the `LOCKDOWN_HIBERNATION` check in native kernel
hibernation, and only with the new `hibernate=allow_locked_down` boot parameter.
Other lockdown checks remain enabled. `nohibernate`, secret-memory restrictions,
and CXL restrictions still apply. The flag becomes read-only after kernel init.
The `/dev/snapshot` userspace API is unchanged.

Upstream authenticated hibernation work is separate. Revisit this exception when
an appropriate upstream implementation is available and reviewed.

## Configuration Guards and Checks

`my.hardware.hibernation.lockdownOverride.enable` defaults to false.
Its read-only `active` flag requires hibernation, the explicit enable, the patch,
and the boot parameter. It describes the configuration, not the running kernel.

The hibernation module rejects these combinations during system evaluation:

- Hibernation plus a `lockdown=` parameter without an active exception.
- Enabling the exception while removing its patch or boot parameter.
- Hibernation with `nohibernate`, even with the exception.
- An exception using a resume device outside the declared initrd LUKS mappers.
- An exception on a kernel series other than Linux 7.3.x, pending patch review.

The mapper guard validates the declared resume device. It cannot prove the
physical layout, passphrase quality, or resume-image authenticity.

## Trusted Kernel Modules

Lockdown also requires trusted module signatures. Lanzaboote's EFI signing key
is separate from the kernel's module keyrings.

The locked Nixpkgs provides deterministic `kmodigest` signatures and certificates
for in-tree and external modules. When
`my.hardware.secure-boot.verifyKernelModules` is enabled, this module:

1. Collects certificates from the complete `system.modulesTree`, including NVIDIA.
2. Uses `boot.kernelPackages.rebuildImage` to embed them into the kernel image.
3. Points both the system's kernel link and its bootspec at that image, so
   Lanzaboote signs the image with the certificates included.
4. Adds `module.sig_enforce=1` to require verification of loaded modules.

Verification defaults to enabled when the host requests lockdown. An assertion
rejects disabling it while using lockdown with this Lanzaboote integration.
This integration is currently limited to these hosts' x86_64 `bzImage` kernels.
External module packages must support Nixpkgs' certificate installation. A
missing certificate must be fixed in that package before deploying.

The hibernation exception requires a full custom kernel build and rebuilds
external modules. Allow substantially more build time than a cached kernel
update. The certificate-bearing image can be rebuilt from the original kernel
build without compiling the whole kernel a second time.

## Build and Verify

Run configuration checks with the public fixture, without deploying it:

```sh
nix flake check --no-build \
  --override-input privacy path:./tests/fixtures/privacy --no-write-lock-file
nix build .#checks.x86_64-linux.boot-security \
  .#checks.x86_64-linux.privacy-schema .#checks.x86_64-linux.monitors \
  .#checks.x86_64-linux.hibernation-kernel \
  --override-input privacy path:./tests/fixtures/privacy --no-write-lock-file
```

Build on the real host with the real private input. Replace `HOST` with the
selected configuration key. Install for the next boot and retain the previous
working generation in the boot menu:

```sh
nixos-rebuild build --flake .#HOST
readlink -f result/kernel
jq -r '."org.nixos.bootspec.v1".kernel' result/boot.json
nixos-rebuild boot --flake .#HOST --sudo
sudo sbctl status
sudo sbctl verify
```

The kernel link and bootspec must name the same `linux-image` path. After reboot:

```sh
uname -r
cat /sys/kernel/security/lockdown
cat /proc/cmdline
cat /sys/power/state
lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS
nvidia-smi
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
sudo journalctl -k -b --grep='lockdown exception|module verification|signature|key.*reject'
```

The lockdown file should select `[integrity]`. The command line should include
`hibernate=allow_locked_down`, `module.sig_enforce=1`, and the expected resume
device and offset, with no `nohibernate`. The power-state list should contain
`disk`. The Btrfs command must agree with `resume_offset`.
resolve any mismatch before hibernating. Check that root and swap remain in LUKS.
Save work, then test `systemctl hibernate`, resume, and
`systemctl suspend-then-hibernate`. Configuration and compile checks cannot
establish the firmware, NVIDIA, or physical resume behaviour.

References:

- [Linux 7.3 hibernation availability check](https://github.com/torvalds/linux/blob/v7.3/kernel/power/hibernate.c)
- [Authenticated hibernation RFC, October 2026](https://www.mail-archive.com/linux-efi%40vger.kernel.org/msg13028.html)
- [Nixpkgs deterministic module verification](https://github.com/NixOS/nixpkgs/pull/571181)
- [Nixpkgs kernel module verification test](https://github.com/NixOS/nixpkgs/blob/3ec636362e1816bc2f0888fa0fa2c69f1bc9e504/nixos/tests/kernel-module-verification.nix)
- [Kernel module signing requirements](https://docs.kernel.org/admin-guide/module-signing.html)
- [Lanzaboote flake setup](https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html#configure-nixos-with-flakes)
- [Removed initrd option](https://github.com/NixOS/nixpkgs/blob/3ec636362e1816bc2f0888fa0fa2c69f1bc9e504/nixos/modules/system/boot/systemd/initrd.nix)
