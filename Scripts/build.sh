#!/bin/bash

FFMPEG_VERSION=7.1.1
FFMPEG_SOURCE_DIR=FFmpeg-n$FFMPEG_VERSION
FFMPEG_LIBS="libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale"
PREFIX=`pwd`/output
ARCH=arm64
PLATFORMS=("iphoneos" "iphonesimulator" "macosx")

if [ ! -d $FFMPEG_SOURCE_DIR ]; then
  echo "Start downloading FFmpeg..."
  curl -LJO https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/n$FFMPEG_VERSION || exit 1
  tar -zxvf FFmpeg-n$FFMPEG_VERSION.tar.gz || exit 1
  rm -f FFmpeg-n$FFMPEG_VERSION.tar.gz
fi

# echo "Start compiling FFmpeg..."

# rm -rf $PREFIX
# mkdir -p $PREFIX

# for PLATFORM in "${PLATFORMS[@]}"; do
#   if [ "$PLATFORM" == "macosx" ]; then
#     SYSROOT=$(xcrun --sdk macosx --show-sdk-path)
#     OS_FLAGS="-mmacosx-version-min=11.0"
#   elif [ "$PLATFORM" == "iphonesimulator" ]; then
#     SYSROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
#     OS_FLAGS="-mios-simulator-version-min=18.0"
#   else
#     SYSROOT=$(xcrun --sdk $PLATFORM --show-sdk-path)
#     OS_FLAGS="-mios-version-min=18.0"
#   fi
#   CC=$(xcrun -sdk $PLATFORM -f clang)
#   TARGET_PREFIX=$PREFIX/$PLATFORM-$ARCH

#   echo "===== Compiling for $PLATFORM ($ARCH) ====="

#   cd $FFMPEG_SOURCE_DIR

#   ./configure \
#     --prefix=$TARGET_PREFIX \
#     --enable-version3 \
#     --disable-programs \
#     --disable-doc \
#     --disable-debug \
#     --disable-videotoolbox \
#     --enable-cross-compile \
#     --target-os=darwin \
#     --arch=$ARCH \
#     --cc="$CC" \
#     --sysroot=$SYSROOT \
#     --extra-cflags="-arch $ARCH -march=native -fno-stack-check $OS_FLAGS" \
#     --extra-ldflags="-arch $ARCH $OS_FLAGS" \
#     --disable-outdev=audiotoolbox || exit 1

#   make clean
#   make -j$(nproc) install || exit 1
#   cd ..
# done

for LIB in $FFMPEG_LIBS; do
  ./build_framework.sh $PREFIX $LIB $FFMPEG_VERSION || exit 1
done

echo "The compilation of FFmpeg is completed."
