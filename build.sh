#!/bin/bash
#
# Compile script for Nyxion kernel.
# Copyright (C) 2020-2021 Adithya R.

##----------------------------------------------------------##

START=$(date +"%s")
ZIPNAME="SW-lavender-4.19-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$(pwd)/tc/clang-r498229"
IMAGE="out/arch/arm64/boot/Image.gz"

DEFCONFIG="lavender_defconfig"

export KBUILD_BUILD_USER="Sã Śâjjãd"
export KBUILD_BUILD_HOST="workdspace"
export KBUILD_COMPILER_STRING="$(${TC_DIR}/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

##----------------------------------------------------------##
post_msg() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
}

##----------------------------------------------------------##

push() {
    curl -F document=@"$1" "https://api.telegram.org/bot$token/sendDocument" \
         -F chat_id="$chat_id" \
         -F "disable_web_page_preview=true" \
         -F "parse_mode=html" \
         -F caption="$2"
}

##----------------------------------------------------------##

if ! [ -d "$TC_DIR" ]; then
    echo "Clang not found, cloning..."
    if ! git clone --depth=1 -b 17 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"; then
        echo "Cloning failed! Aborting..."
        exit 1
    fi
fi

##----------------------------------------------------------##

case "$1" in
    -r|--regen)
        make O=out ARCH=arm64 $DEFCONFIG savedefconfig && cp out/defconfig arch/arm64/configs/$DEFCONFIG
        echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
        exit
        ;;
    -rf|--regen-full)
        make O=out ARCH=arm64 $DEFCONFIG && cp out/.config arch/arm64/configs/$DEFCONFIG
        echo -e "\nSuccessfully regenerated full defconfig at $DEFCONFIG"
        exit
        ;;
    -c|--clean)
        rm -rf out
        ;;
    -up|--package)
        echo -e "\n Installing required package"
        sudo apt update && sudo apt install -y cpio flex bison bc libarchive-tools zstd wget curl
        ;;
esac

##----------------------------------------------------------##

compile() {
    export PATH="$TC_DIR/bin:$PATH"
    post_msg "<b>CI Build Triggered</b>%0A<b>Kernel Version:</b> <code>$(make kernelversion)</code>%0A<b>Date:</b> <code>$(TZ=Asia/Kolkata date)</code>%0A<b>Device:</b> <code>Redmi Note 7 (lavender)</code>%0A<b>Compiler:</b> <code>$KBUILD_COMPILER_STRING</code>%0A<b>Branch:</b> <code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Top Commit:</b> <code>$(git log --pretty=format:'%h : %s' -1)</code>"

    mkdir -p out
    make O=out ARCH=arm64 $DEFCONFIG
    make -j$(nproc) ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 "$DEFCONFIG" O=out

    echo -e "\nStarting compilation...\n"
    make -j$(nproc) ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 O=out 2>&1 | tee error.log

    if ! [ -f "$IMAGE" ]; then
        push "error.log" "Build failed. See log for details."
        exit 1
    fi

    git clone -q https://github.com/Sa-Sajjad/AnyKernel3 -b 4.19
    cp "$IMAGE" AnyKernel3
}

##----------------------------------------------------------##

zipping() {
    cd AnyKernel3 || exit 1
    zip -r9 "../$ZIPNAME" *
    cd ..
    push "$ZIPNAME" "Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s) %0A $ZIPNAME"
    rm -rf AnyKernel3
}

##----------------------------------------------------------##

compile
END=$(date +"%s")
DIFF=$(($END - $START))
zipping

##----------------------------------------------------------##
