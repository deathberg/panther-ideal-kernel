#!/usr/bin/env bash
# panther-ideal kernel build: Sultan gs201 (A16, 6.1) + KernelSU-Next built-in + SUSFS
# Recipe follows the proven mrvokintos/Sultan_KernelSU_SUSFS flow.
# usage: build.sh <variant: ksun-susfs|ksun|stock> <susfs_branch>
set -e
VARIANT="${1:-ksun-susfs}"
SUSFS_BRANCH="${2:-gki-android14-6.1}"
CODENAME=gs201
CONFIG=android_kernel_google_tensynos

wget -q https://www.kernel.org/pub/tools/crosstool/files/bin/x86_64/14.2.0/x86_64-gcc-14.2.0-nolibc-aarch64-linux.tar.gz
gunzip -f x86_64-gcc-14.2.0-nolibc-aarch64-linux.tar.gz
tar -xf x86_64-gcc-14.2.0-nolibc-aarch64-linux.tar

git clone https://github.com/TheWildJames/AnyKernel3.git -b "sultan-$CODENAME"
git clone https://github.com/WildKernels/kernel_patches.git
git clone https://github.com/kerneltoast/android_kernel_google_tensynos --depth=1
if [ "$VARIANT" = "ksun-susfs" ]; then
  git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "$SUSFS_BRANCH"
fi

cd "$CONFIG"

if [ "$VARIANT" != "stock" ]; then
  curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/dev/kernel/setup.sh" | bash -s dev
fi

if [ "$VARIANT" = "ksun-susfs" ]; then
  SUSFS_VERSION="2.2.0"

  cp ../susfs4ksu/kernel_patches/50_add_susfs_in_${SUSFS_BRANCH}.patch ./
  mkdir -p ./fs/ ./include/linux/
  cp ../susfs4ksu/kernel_patches/fs/* ./fs/ 2>/dev/null || true
  cp ../susfs4ksu/kernel_patches/include/linux/* ./include/linux/ 2>/dev/null || true

  echo "Patching KernelSU-Next for SUSFS..."
  cd KernelSU-Next
  cp ../../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./
  patch -p1 < 10_enable_susfs_for_ksu.patch || true
  for p in "../../kernel_patches/next/susfs_fix_patches/stable/v${SUSFS_VERSION}/"*.patch; do
    echo "applying $(basename "$p")"
    patch -p1 < "$p" || true
  done
  cd ..

  patch -p1 < "50_add_susfs_in_${SUSFS_BRANCH}.patch" || true

  echo "Applying Sultan-specific patches..."
  [ -f ../kernel_patches/sultan/fix_base.c.patch ] && patch -p1 < ../kernel_patches/sultan/fix_base.c.patch || true
  [ -f ../kernel_patches/sultan/sys.c_fix.patch ] && patch -p1 < ../kernel_patches/sultan/sys.c_fix.patch || true
fi

if [ "$VARIANT" != "stock" ]; then
  D="./arch/arm64/configs/${CODENAME}_defconfig"
  {
    echo "# panther-ideal"
    echo "CONFIG_KSU=y"
    if [ "$VARIANT" = "ksun-susfs" ]; then
      echo "CONFIG_KSU_SUSFS=y"
    else
      echo "CONFIG_KSU_SUSFS=n"
    fi
  } >> "$D"
  cat "$GITHUB_WORKSPACE/ci/extra_defconfig.txt" >> "$D"
fi

D="./arch/arm64/configs/${CODENAME}_defconfig"
if grep -q '^CONFIG_LOCALVERSION=' "$D"; then
  sed -i 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-ideal"/' "$D"
else
  echo 'CONFIG_LOCALVERSION="-ideal"' >> "$D"
fi
if grep -q '^CONFIG_LOCALVERSION_AUTO=' "$D"; then
  sed -i 's/^CONFIG_LOCALVERSION_AUTO=.*/CONFIG_LOCALVERSION_AUTO=n/' "$D"
else
  echo 'CONFIG_LOCALVERSION_AUTO=n' >> "$D"
fi

GCC="$GITHUB_WORKSPACE/gcc-14.2.0-nolibc/aarch64-linux/bin/aarch64-linux-"
make CROSS_COMPILE="$GCC" CC="${GCC}gcc" -j"$(nproc --all)" "${CODENAME}_defconfig"
make CROSS_COMPILE="$GCC" CC="${GCC}gcc" -j"$(nproc --all)"

cp out/arch/arm64/boot/Image.lz4 ../AnyKernel3/Image.lz4
cat out/google-devices/gs201/dts/*.dtb > ../AnyKernel3/dtb

( cd ../AnyKernel3 && zip -r "../${CODENAME}-a16-ideal-${VARIANT}-anykernel3.zip" ./* )
