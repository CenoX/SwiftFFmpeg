#!/bin/bash

PREFIX=$1
LIB_NAME=$2
LIB_VERSION=$3
PLATFORMS=("ios" "iphonesimulator" "macosx" "maccatalyst")
LIB_XCFRAMEWORK=$PREFIX/xcframework/$LIB_NAME.xcframework

for PLATFORM in "${PLATFORMS[@]}"; do
	FRAMEWORK_PARENT_DIR=$PREFIX/framework/$PLATFORM

	if [[ "$PLATFORM" == "ios" ]]; then
    	HEADER_PATH="iphoneos-arm64"
		LIB_PATH="iphoneos-arm64"
		LIB_UNIV_PATH="iphoneos-universal"
		TARGET="iPhoneOS"
	elif [[ "$PLATFORM" == "iphonesimulator" ]]; then
    	HEADER_PATH="iphonesimulator-arm64"
		LIB_PATH="iphonesimulator-universal"
		TARGET="iPhoneSimulator"
	elif [[ "$PLATFORM" == "macosx" ]]; then
    	HEADER_PATH="macosx-arm64"
		LIB_PATH="macosx-universal"
		TARGET="MacOSX"
	elif [[ "$PLATFORM" == "maccatalyst" ]]; then
		HEADER_PATH="maccatalyst-arm64"
		LIB_PATH="maccatalyst-universal"
		TARGET="MacOSX"
	else
		echo "❌ Unknown platform: $PLATFORM"
		exit 1
	fi

	LIB_FRAMEWORK=$FRAMEWORK_PARENT_DIR/$LIB_NAME.framework

	# save xcframework input variable
	if [[ "$PLATFORM" == "ios" ]]; then
		LIB_DEVICE=$LIB_FRAMEWORK
	elif [[ "$PLATFORM" == "iphonesimulator" ]]; then
		LIB_SIM=$LIB_FRAMEWORK
	elif [[ "$PLATFORM" == "maccatalyst" ]]; then
		LIB_CATALYST=$LIB_FRAMEWORK
	else
		LIB_MACOS=$LIB_FRAMEWORK
	fi

	# build framework
	rm -rf $LIB_FRAMEWORK
	mkdir -p $LIB_FRAMEWORK/Headers

	cp -R $PREFIX/$HEADER_PATH/include/$LIB_NAME/* $LIB_FRAMEWORK/Headers/
	libtool -static -o $LIB_FRAMEWORK/$LIB_NAME $PREFIX/$LIB_PATH/lib/$LIB_NAME.a

	cat > $LIB_FRAMEWORK/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$LIB_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>org.ffmpeg.$LIB_NAME</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$LIB_NAME</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>MinimumOSVersion</key>
	<string>18.0</string>
	<key>CFBundleShortVersionString</key>
	<string>$LIB_VERSION</string>
	<key>CFBundleVersion</key>
	<string>$LIB_VERSION</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>$TARGET</string>
	</array>
</dict>
</plist>
EOF

done

# build xcframework
rm -rf $LIB_XCFRAMEWORK

xcodebuild \
	-verbose \
	-create-xcframework \
	-framework $LIB_DEVICE \
	-framework $LIB_SIM \
	-framework $LIB_MACOS \
	-framework $LIB_CATALYST \
	-output $LIB_XCFRAMEWORK

# error: unable to find any specific architecture information in the binary at xxx

mkdir -p $LIB_XCFRAMEWORK/ios-arm64
mkdir -p $LIB_XCFRAMEWORK/ios-arm64_x86_64-simulator
mkdir -p $LIB_XCFRAMEWORK/macos-arm64_x86_64
mkdir -p $LIB_XCFRAMEWORK/maccatalyst-arm64_x86_64

cp -R $LIB_DEVICE $LIB_XCFRAMEWORK/ios-arm64
cp -R $LIB_SIM $LIB_XCFRAMEWORK/ios-arm64_x86_64-simulator
cp -R $LIB_MACOS $LIB_XCFRAMEWORK/macos-arm64_x86_64
cp -R $LIB_CATALYST $LIB_XCFRAMEWORK/maccatalyst-arm64_x86_64

cat > $LIB_XCFRAMEWORK/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AvailableLibraries</key>
	<array>
		<dict>
			<key>LibraryIdentifier</key>
			<string>ios-arm64</string>
			<key>LibraryPath</key>
			<string>$LIB_NAME.framework</string>
			<key>SupportedArchitectures</key>
			<array>
			<string>arm64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>ios</string>
		</dict>
		<dict>
			<key>LibraryIdentifier</key>
			<string>maccatalyst-arm64_x86_64</string>
			<key>LibraryPath</key>
			<string>$LIB_NAME.framework</string>
			<key>SupportedArchitectures</key>
			<array>
			<string>arm64</string>
			<string>x86_64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>ios</string>
			<key>SupportedPlatformVariant</key>
			<string>maccatalyst</string>
		</dict>
		<dict>
			<key>LibraryIdentifier</key>
			<string>ios-arm64_x86_64-simulator</string>
			<key>LibraryPath</key>
			<string>$LIB_NAME.framework</string>
			<key>SupportedArchitectures</key>
			<array>
			<string>x86_64</string>
			<string>arm64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>ios</string>
			<key>SupportedPlatformVariant</key>
			<string>simulator</string>
		</dict>
		<dict>
			<key>LibraryIdentifier</key>
			<string>macos-arm64_x86_64</string>
			<key>LibraryPath</key>
			<string>$LIB_NAME.framework</string>
			<key>SupportedArchitectures</key>
			<array>
			<string>x86_64</string>
			<string>arm64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>macos</string>
		</dict>
	</array>
	<key>CFBundlePackageType</key>
	<string>XFWK</string>
	<key>XCFrameworkFormatVersion</key>
	<string>1.0</string>
</dict>
</plist>
EOF

codesign --force --sign "Apple Distribution: Byeong-Su Kang (UP6EXS2HJJ)" --timestamp=none --deep --options=runtime $LIB_XCFRAMEWORK