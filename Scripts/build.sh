#!/bin/bash

FFMPEG_VERSION=8.1.3
FFMPEG_SOURCE_DIR=FFmpeg-n$FFMPEG_VERSION
FFMPEG_LIBS="libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale"
PREFIX=`pwd`/output
ARCHS=("arm64" "x86_64")
PLATFORMS=("iphoneos" "iphonesimulator" "macosx" "maccatalyst")

if [ ! -d $FFMPEG_SOURCE_DIR ]; then
  echo "Start downloading FFmpeg..."
  curl -LJO https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/n$FFMPEG_VERSION || exit 1
  tar -zxvf FFmpeg-n$FFMPEG_VERSION.tar.gz || exit 1
  rm -f FFmpeg-n$FFMPEG_VERSION.tar.gz
fi

echo "Start compiling FFmpeg..."

rm -rf $PREFIX
mkdir -p $PREFIX

for PLATFORM in "${PLATFORMS[@]}"; do
  for ARCH in "${ARCHS[@]}"; do

    # no need to build x86_64 for iPhoneOS
    if [[ "$PLATFORM" == "iphoneos" && "$ARCH" == "x86_64" ]]; then continue; fi

    echo "Building for $PLATFORM - $ARCH"

    # Set per iteration so a stale value from the previous platform cannot leak in.
    #
    # VideoToolbox DECODE only. Dropping --disable-videotoolbox also enables the
    # h264/hevc/prores VideoToolbox *encoders*, which silently changes encoder
    # discovery: this configuration has no software H.264/HEVC encoder, so
    # avcodec_find_encoder(AV_CODEC_ID_H264) flips from NULL to
    # h264_videotoolbox. A caller that only asks by codec id would start
    # hardware-encoding without ever requesting it. Keep the scope to decoding;
    # delete that line to enable hardware encoding deliberately.
    #
    # The VideoToolbox *filters* (yadif_videotoolbox, transpose_vt, scale_vt) come
    # along too. They only operate on VideoToolbox frames, they change what
    # avfilter enumerates, and yadif_videotoolbox drags in a Metal link
    # dependency (MTLCreateSystemDefaultDevice) that consumers would have to
    # satisfy. Not needed for decoding, so leave them out.
    CONFIGURE_HWACCEL_OPTIONS="--disable-encoder=h264_videotoolbox,hevc_videotoolbox,prores_videotoolbox"
    CONFIGURE_HWACCEL_OPTIONS="$CONFIGURE_HWACCEL_OPTIONS --disable-filter=yadif_videotoolbox,transpose_vt,scale_vt"

    if [ "$PLATFORM" == "macosx" ]; then
      SYSROOT=$(xcrun --sdk macosx --show-sdk-path)
      OS_FLAGS="-mmacosx-version-min=11.0 -isysroot $SYSROOT"
      CC=$(xcrun -sdk $PLATFORM -f clang)
    elif [ "$PLATFORM" == "iphonesimulator" ]; then
      SYSROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
      OS_FLAGS="-mios-simulator-version-min=18.0 -isysroot $SYSROOT"
      CC=$(xcrun -sdk $PLATFORM -f clang)
    elif [ "$PLATFORM" == "maccatalyst" ]; then
      SYSROOT=$(xcrun --sdk macosx --show-sdk-path)
      OS_FLAGS="-target $ARCH-apple-ios18.0-macabi -isysroot $SYSROOT"
      CC=$(xcrun -sdk macosx -f clang)
      CONFIGURE_TLS_OPTIONS="--disable-securetransport"
      # Mac Catalyst is a shipping slice, but it cannot compile VideoToolbox.
      #
      # FFmpeg's libavcodec/videotoolbox.c guards on `#if TARGET_OS_IPHONE`,
      # which is 1 for Mac Catalyst, so it reaches for
      # kCVPixelBufferOpenGLESCompatibilityKey -- a symbol the SDK marks
      # API_UNAVAILABLE(macCatalyst) (CVPixelBuffer.h:246). The build fails to
      # compile as a result (FFmpeg 8.1.3, libavcodec/videotoolbox.c:821).
      #
      # The real fix belongs upstream and is one line:
      #     #if TARGET_OS_IPHONE && !TARGET_OS_MACCATALYST
      # The key genuinely does not exist on Catalyst, so not setting it is the
      # correct behaviour, not a workaround. Applying it here would mean
      # patching vendored FFmpeg sources on every version bump, which is a
      # separate decision -- and hardware decoding is not consumed yet anyway.
      # Still unfixed on FFmpeg master as of 2026-10-21 (same guard, and
      # TARGET_OS_MACCATALYST appears nowhere in the tree).
      #
      # So VideoToolbox is disabled for this slice only. The maccatalyst slice
      # therefore has NO hardware decode: a deliberate trade-off forced by the
      # upstream conflict, NOT a decision to drop Catalyst support.
      CONFIGURE_HWACCEL_OPTIONS="--disable-videotoolbox"
    else
      SYSROOT=$(xcrun --sdk iphoneos --show-sdk-path)
      OS_FLAGS="-mios-version-min=18.0 -isysroot $SYSROOT"
      CC=$(xcrun -sdk $PLATFORM -f clang)
      CONFIGURE_TLS_OPTIONS="--enable-securetransport"
    fi

    TARGET_PREFIX="$PREFIX/$PLATFORM-$ARCH"

    cd $FFMPEG_SOURCE_DIR
    make clean

    ./configure \
      --prefix=$TARGET_PREFIX \
      --enable-cross-compile \
      --target-os=darwin \
      --arch=$ARCH \
      --cc="$CC" \
      --sysroot=$SYSROOT \
      --extra-cflags="-arch $ARCH $OS_FLAGS" \
      --extra-ldflags="-arch $ARCH $OS_FLAGS" \
      --disable-programs \
      --disable-doc \
      --disable-debug \
      --enable-version3 \
      --disable-coreimage \
      --disable-outdev=audiotoolbox \
      $CONFIGURE_TLS_OPTIONS \
      $CONFIGURE_HWACCEL_OPTIONS || exit 1

    make -j$(sysctl -n hw.logicalcpu) install || exit 1
    cd ..
  done
done

for LIB in $FFMPEG_LIBS; do
  for PLATFORM in "iphonesimulator" "macosx" "maccatalyst"; do
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
