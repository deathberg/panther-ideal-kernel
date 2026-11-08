#!/usr/bin/env bash
# panther-ideal kernel build: Sultan gs201 (A16, 6.1) + KernelSU-Next built-in + SUSFS
# usage: build.sh <variant: ksun-susfs|ksun|stock> <susfs_branch>
set -e
VARIANT="${1:-ksun-susfs}"
SUSFS_BRANCH="${2:-gki-android14-6.1}"
CODENAME=gs201

wget -q https://www.kernel.org/pub/tools/crosstool/files/bin/x86_64/14.2.0/x86_64-gcc-14.2.0-nolibc-aarch64-linux.tar.gz
gunzip -f x86_64-gcc-14.2.0-nolibc-aarch64-linux.tar.gz
tar -xf x86_64-gcc-14.2.0-nolibc-aarch64-linux.tar

git clone https://github.com/TheWildJames/AnyKernel3.git -b "sultan-$CODENAME"
git clone https://github.com/TheWildJames/kernel_patches.git
git clone https://github.com/TheWildJames/android_kernel_google_tensynos --depth=1
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "$SUSFS_BRANCH"

cd android_kernel_google_tensynos

if [ "$VARIANT" != "stock" ]; then
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
fi

if [ "$VARIANT" = "ksun-susfs" ]; then
  ( cd ../susfs4ksu
    patch -p1 < "$GITHUB_WORKSPACE/kernel_patches/pershoot/susfs4ksu/0001-pershoot-Allow-core-to-be-built-with-no-features.patch"
    patch -p1 < "$GITHUB_WORKSPACE/kernel_patches/pershoot/susfs4ksu/0002-pershoot-Implement-SuSFS-and-Toolkit-coexistence.patch" )
  cp ../susfs4ksu/kernel_patches/fs/* ./fs/
  cp ../susfs4ksu/kernel_patches/include/linux/* ./include/linux/
  perl -0pi -e 's/if \(IS_ERR\(f\) && !libperfmgr_redirect\(&f, dfd, tmp, &op, how\)\) \{/if (IS_ERR(f)) {/g' fs/open.c
  patch -p1 < "../susfs4ksu/kernel_patches/50_add_susfs_in_${SUSFS_BRANCH}.patch" || true
  perl -0pi -e 's/if \(IS_ERR\(f\)\) \{/if (IS_ERR(f) && !libperfmgr_redirect(&f, dfd, tmp, &op, how)) {/g' fs/open.c
  patch -p1 < ../kernel_patches/sultan/sys.c_fix.patch
fi

if [ "$VARIANT" != "stock" ]; then
  D="./arch/arm64/configs/${CODENAME}_defconfig"
  echo "CONFIG_KSU=y" >> "$D"
  if [ "$VARIANT" = "ksun-susfs" ]; then
    echo "CONFIG_KSU_SUSFS=y" >> "$D"
  else
    echo "CONFIG_KSU_MANUAL_HOOKS=y" >> "$D"
    echo "CONFIG_KSU_SUSFS=n" >> "$D"
  fi
  cat "$GITHUB_WORKSPACE/ci/extra_defconfig.txt" >> "$D"
  if [ "$VARIANT" = "ksun" ]; then
    patch -p1 < ../kernel_patches/wild/hooks/69_pure_manual_hooks_only.patch
  fi
  sed -i 's/CONFIG_LOCALVERSION="-Sultan"/CONFIG_LOCALVERSION="-Sultan-ideal"/' "$D"
  sed -i '/echo "+"$/d' scripts/setlocalversion
fi

GCC="$GITHUB_WORKSPACE/gcc-14.2.0-nolibc/aarch64-linux/bin/aarch64-linux-"
make CROSS_COMPILE="$GCC" CC="${GCC}gcc" -j"$(nproc --all)" "${CODENAME}_defconfig"
make CROSS_COMPILE="$GCC" CC="${GCC}gcc" LOCALVERSION_AUTO=0 -j"$(nproc --all)"

cp out/arch/arm64/boot/Image.lz4 ../AnyKernel3/Image.lz4
( cd ../AnyKernel3 && zip -r "../${CODENAME}-a16-ideal-${VARIANT}-anykernel3.zip" ./* )
