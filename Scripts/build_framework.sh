#!/bin/bash

PREFIX=$1
LIB_NAME=$2
LIB_VERSION=$3
PLATFORMS=("ios" "iphonesimulator" "macosx")
LIB_XCFRAMEWORK=$PREFIX/xcframework/$LIB_NAME.xcframework

for PLATFORM in "${PLATFORMS[@]}"; do
	FRAMEWORK_PARENT_DIR=$PREFIX/framework/$PLATFORM

	if [[ "$PLATFORM" == "ios" ]]; then
		SDK_PLATFORM="iphoneos-arm64"
		TARGET="iPhoneOS"
	elif [[ "$PLATFORM" == "iphonesimulator" ]]; then
		SDK_PLATFORM="iphonesimulator-arm64"
		TARGET="iPhoneSimulator"
	elif [[ "$PLATFORM" == "macosx" ]]; then
		SDK_PLATFORM="macosx-arm64"
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
	else
		LIB_MACOS=$LIB_FRAMEWORK
	fi

	# build framework
	rm -rf $LIB_FRAMEWORK
	mkdir -p $LIB_FRAMEWORK/Headers

	cp -R $PREFIX/$SDK_PLATFORM/include/$LIB_NAME/* $LIB_FRAMEWORK/Headers/
	libtool -static -o $LIB_FRAMEWORK/$LIB_NAME $PREFIX/$SDK_PLATFORM/lib/$LIB_NAME.a

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
	-output $LIB_XCFRAMEWORK

# error: unable to find any specific architecture information in the binary at xxx

mkdir -p $LIB_XCFRAMEWORK/ios-arm64
mkdir -p $LIB_XCFRAMEWORK/iossim-arm64
mkdir -p $LIB_XCFRAMEWORK/macos-arm64

cp -R $LIB_DEVICE $LIB_XCFRAMEWORK/ios-arm64
cp -R $LIB_SIM $LIB_XCFRAMEWORK/iossim-arm64
cp -R $LIB_MACOS $LIB_XCFRAMEWORK/macos-arm64

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
			<string>ios-arm64-simulator</string>
			<key>LibraryPath</key>
			<string>$LIB_NAME.framework</string>
			<key>SupportedArchitectures</key>
			<array>
				<string>arm64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>iossimulator</string>
		</dict>
		<dict>
			<key>LibraryIdentifier</key>
			<string>iossim-arm64</string>
			<key>LibraryPath</key>
			<string>$LIB_NAME.framework</string>
			<key>SupportedArchitectures</key>
			<array>
				<string>arm64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>iphonesimulator</string>
		</dict>
		<dict>
			<key>LibraryIdentifier</key>
			<string>macos-arm64</string>
			<key>LibraryPath</key>
			<string>$LIB_NAME.framework</string>
			<key>SupportedArchitectures</key>
			<array>
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
