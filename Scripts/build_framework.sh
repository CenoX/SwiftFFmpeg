#!/bin/bash

PREFIX=$1
LIB_NAME=$2
LIB_VERSION=$3
PLATFORMS=("ios-arm64" "ios-arm64-simulator")
LIB_XCFRAMEWORK=$PREFIX/xcframework/$LIB_NAME.xcframework

for PLATFORM in "${PLATFORMS[@]}"; do
	if [[ "$PLATFORM" == "ios-arm64" ]]; then
		SDK_PLATFORM="iphoneos-arm64"
	elif [[ "$PLATFORM" == "ios-arm64-simulator" ]]; then
		SDK_PLATFORM="iphonesimulator-arm64"
	else
		echo "❌ Unknown platform: $PLATFORM"
		exit 1
	fi

	# framework/ios-arm64/libavcodec.framework
	FRAMEWORK_PARENT_DIR=$PREFIX/framework/$PLATFORM
	LIB_FRAMEWORK=$FRAMEWORK_PARENT_DIR/$LIB_NAME.framework

	# save xcframework input variable
	if [[ "$PLATFORM" == "ios-arm64" ]]; then
		LIB_DEVICE=$LIB_FRAMEWORK
	else
		LIB_SIMULATOR=$LIB_FRAMEWORK
	fi

	# build framework
	rm -rf $LIB_FRAMEWORK
	mkdir -p $LIB_FRAMEWORK/Headers

	cp -R $PREFIX/$SDK_PLATFORM/include/$LIB_NAME/* $LIB_FRAMEWORK/Headers/
	cp $PREFIX/$SDK_PLATFORM/lib/$LIB_NAME.a $LIB_FRAMEWORK/$LIB_NAME

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
	<key>CFBundleShortVersionString</key>
	<string>$LIB_VERSION</string>
	<key>CFBundleVersion</key>
	<string>$LIB_VERSION</string>
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
	-output $LIB_XCFRAMEWORK

# error: unable to find any specific architecture information in the binary at xxx

mkdir -p $LIB_XCFRAMEWORK/ios-arm64
# mkdir -p $LIB_XCFRAMEWORK/ios-arm64-simulator
cp -R $LIB_DEVICE $LIB_XCFRAMEWORK/ios-arm64
# cp -R $LIB_SIMULATOR $LIB_XCFRAMEWORK/ios-arm64-simulator

# error: unable to make xcframework with the following architectures: ios-arm64-simulator

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
	</array>
	<key>CFBundlePackageType</key>
	<string>XFWK</string>
	<key>XCFrameworkFormatVersion</key>
	<string>1.0</string>
</dict>
</plist>
EOF
