#!/usr/bin/env bash

sudo apt-get install clang-format clang-tidy clang-tools clang clangd libc++-dev libc++1 libc++abi-dev libc++abi1 libclang-dev libclang1 liblldb-dev libllvm-ocaml-dev libomp-dev libomp5 lld lldb llvm-dev llvm-runtime llvm python3-clang -y
sudo apt-get install gcc-aarch64-linux-gnu bc -y

set -e

KERNEL_DIR="$(pwd)"
CHAT_ID="7861399342"
TOKEN="8188281304:AAGd1EB1FqT4NQjOgS7p4IfPyjYRXjHvIMw"
DEVICE="gale"
KERVER=$(make -s kernelversion | tr -d '[:space:]')
VERSION=v1
DEFCONFIG="gale_defconfig"
IMAGE=${KERNEL_DIR}/out/arch/arm64/boot/Image.gz-dtb
ZIPNAME="coloroxkernel"
TANGGAL=$(date +"%F-%H%M")
FINAL_ZIP="${ZIPNAME}-${VERSION}-${KERVER}-${DEVICE}-${TANGGAL}.zip"
COMPILER="llvm"
VERBOSE=0

telegram_push() {
  curl --progress-bar -F document=@"$1" https://api.telegram.org/bot$TOKEN/sendDocument \
	-F chat_id="$CHAT_ID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2"
}

if [ "$COMPILER" = "llvm" ]; then
    mkdir -p clang
    cd clang || exit 1
    wget -q https://github.com/ZyCromerZ/Clang/releases/download/21.0.0git-20250228-release/Clang-21.0.0git-20250228.tar.gz
    tar -xf Clang*
    cd "$KERNEL_DIR" || exit 1
    PATH="${KERNEL_DIR}/clang/bin:$PATH"
elif [ "$COMPILER" = "aosp" ]; then
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git --depth=1 gcc
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git --depth=1 gcc32
    PATH="${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:${PATH}"
fi

git clone https://github.com/Mohamedfullhd/AnyKernel3.git --depth=1

KBUILD_BUILD_HOST="LR"
KBUILD_BUILD_USER="-4k"
KBUILD_COMPILER_STRING=$(clang --version | head -n 1 | perl -pe 's/http.*?//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
PROCS=$(nproc --all)
export KBUILD_COMPILER_STRING KBUILD_BUILD_USER KBUILD_BUILD_HOST PROCS

function compile() {
    START=$(date +"%s")
    MAKE_OPT=()

    if [ "$COMPILER" = "llvm" ]; then
        MAKE_OPT+=(CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-)
    elif [ "$COMPILER" = "aosp" ]; then
        MAKE_OPT+=(CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_ARM32=arm-linux-androideabi-)
    fi

    make O=out ARCH=arm64 $DEFCONFIG LLVM=1
    make -kj"$PROCS" O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 V=$VERBOSE "${MAKE_OPT[@]}" 2>&1 | tee error.log

    END=$(date +"%s")
    DIFF=$((END - START))
}

function zipping() {
    if [ ! -f "$IMAGE" ]; then
        telegram_push "error.log" "**Build Failed:** Kernel compilation threw errors"
        exit 1
    else
        cp "$IMAGE" AnyKernel3
        cd AnyKernel3 || exit 1
        echo "Generating ZIP: ${FINAL_ZIP}"
        zip -r9 "${FINAL_ZIP}" * -x .git README.md
        cd "$KERNEL_DIR" || exit 1
    fi
}

function upload() {
    telegram_push "AnyKernel3/${FINAL_ZIP}" "Build took : $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)"
    exit 0
}

compile
zipping
upload
