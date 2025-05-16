#!/bin/bash

FFMPEG_VERSION=7.1.1
FFMPEG_SOURCE_DIR=FFmpeg-n$FFMPEG_VERSION
FFMPEG_LIBS="libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale"
PREFIX=`pwd`/output
ARCHS=("arm64" "x86_64")
PLATFORMS=("iphoneos" "iphonesimulator" "macosx")

# if [ ! -d $FFMPEG_SOURCE_DIR ]; then
#   echo "Start downloading FFmpeg..."
#   curl -LJO https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/n$FFMPEG_VERSION || exit 1
#   tar -zxvf FFmpeg-n$FFMPEG_VERSION.tar.gz || exit 1
#   rm -f FFmpeg-n$FFMPEG_VERSION.tar.gz
# fi

# echo "Start compiling FFmpeg..."

# rm -rf $PREFIX
# mkdir -p $PREFIX

# for PLATFORM in "${PLATFORMS[@]}"; do
#   for ARCH in "${ARCHS[@]}"; do

#     # no need to build x86_64 for iPhoneOS
#     if [[ "$PLATFORM" == "iphoneos" && "$ARCH" == "x86_64" ]]; then continue; fi

#     echo "Building for $PLATFORM - $ARCH"

#     if [ "$PLATFORM" == "macosx" ]; then
#       SYSROOT=$(xcrun --sdk macosx --show-sdk-path)
#       OS_FLAGS="-mmacosx-version-min=11.0"
#     elif [ "$PLATFORM" == "iphonesimulator" ]; then
#       SYSROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
#       OS_FLAGS="-mios-simulator-version-min=18.0"
#     else
#       SYSROOT=$(xcrun --sdk iphoneos --show-sdk-path)
#       OS_FLAGS="-mios-version-min=18.0"
#     fi

#     TARGET_PREFIX="$PREFIX/$PLATFORM-$ARCH"
#     CC=$(xcrun -sdk $PLATFORM -f clang)

#     cd $FFMPEG_SOURCE_DIR
#     make clean

#     ./configure \
#       --prefix=$TARGET_PREFIX \
#       --enable-cross-compile \
#       --target-os=darwin \
#       --arch=$ARCH \
#       --cc="$CC" \
#       --sysroot=$SYSROOT \
#       --extra-cflags="-arch $ARCH $OS_FLAGS" \
#       --extra-ldflags="-arch $ARCH $OS_FLAGS" \
#       --disable-programs \
#       --disable-doc \
#       --disable-debug \
#       --enable-version3 \
#       --disable-outdev=audiotoolbox \
#       --disable-videotoolbox || exit 1

#     make -j$(sysctl -n hw.logicalcpu) install || exit 1
#     cd ..
#   done
# done

for LIB in $FFMPEG_LIBS; do
  for PLATFORM in "iphonesimulator" "macosx"; do
    echo "Creating fat binary for $LIB ($PLATFORM)"
    mkdir -p "$PREFIX/$PLATFORM-universal/lib"
    lipo -create \
      "$PREFIX/$PLATFORM-arm64/lib/$LIB.a" \
      "$PREFIX/$PLATFORM-x86_64/lib/$LIB.a" \
      -output "$PREFIX/$PLATFORM-universal/lib/$LIB.a"
  done
done

for LIB in $FFMPEG_LIBS; do
  ./build_framework.sh $PREFIX $LIB $FFMPEG_VERSION || exit 1
done

echo "The compilation of FFmpeg is completed."
