#!/bin/bash

FFMPEG_VERSION=7.1.1
FFMPEG_SOURCE_DIR=FFmpeg-n$FFMPEG_VERSION
FFMPEG_LIBS="libavcodec libavdevice libavfilter libavformat libavutil libpostproc libswresample libswscale"
PREFIX=`pwd`/output
ARCH="arm64"

if [ ! -d $FFMPEG_SOURCE_DIR ]; then
  echo "Start downloading FFmpeg..."
  curl -LJO https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/n$FFMPEG_VERSION || exit 1
  tar -zxvf FFmpeg-n$FFMPEG_VERSION.tar.gz || exit 1
  rm -f FFmpeg-n$FFMPEG_VERSION.tar.gz
fi

echo "Start compiling FFmpeg..."

rm -rf $PREFIX
cd $FFMPEG_SOURCE_DIR

./configure \
  --prefix=$PREFIX \
  --enable-version3 \
  --disable-programs \
  --enable-cross-compile \
  --target-os=darwin \
  --disable-indev=audiotoolbox \
  --disable-outdev=audiotoolbox \
  --cc="$(xcrun -sdk iphoneos -f clang)" \
  --sysroot=$(xcrun --sdk iphoneos --show-sdk-path) \
  --disable-doc \
  --arch=$ARCH \
  --extra-cflags="-arch $ARCH -march=native -fno-stack-check  -mios-version-min=18.0" \
  --extra-ldflags="-arch $ARCH -mios-version-min=18.0" \
  --disable-debug || exit 1

make clean
make -j$(nproc) install || exit 1

cd ..

for LIB in $FFMPEG_LIBS; do
  ./build_framework.sh $PREFIX $LIB $FFMPEG_VERSION || exit 1
done

echo "The compilation of FFmpeg is completed."
