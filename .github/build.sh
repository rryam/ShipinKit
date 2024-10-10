#!/bin/bash

set -e

XCODEBUILD_DERIVED_DATA_PATH="./DerivedData"

PACKAGE_NAME=$1
if [ -z "$PACKAGE_NAME" ]; then
    echo "No package name provided. Using the first scheme found in the Package.swift."
    PACKAGE_NAME=$(xcodebuild -list | awk 'schemes && NF>0 { print $1; exit } /Schemes:$/ { schemes = 1 }')
    echo "Using: $PACKAGE_NAME"
fi

build_framework() {
    local sdk="$1"
    local destination="$2"
    local scheme="$3"

    local XCODEBUILD_ARCHIVE_PATH="./$scheme-$sdk.xcarchive"

    rm -rf "$XCODEBUILD_ARCHIVE_PATH"

    xcodebuild archive \
        -scheme "$scheme" \
        -archivePath "$XCODEBUILD_ARCHIVE_PATH" \
        -sdk "$sdk" \
        -destination "$destination" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        INSTALL_PATH='Library/Frameworks' \
        OTHER_SWIFT_FLAGS='-no-verify-emitted-module-interface'
}

# Remove the sed command if Package.swift is already correctly configured
sed -i '' '/Replace this/ s/.*/type: .dynamic,/' Package.swift

build_framework "iphonesimulator" "generic/platform=iOS Simulator" "$PACKAGE_NAME"
build_framework "iphoneos" "generic/platform=iOS" "$PACKAGE_NAME"

echo "Builds completed successfully."

rm -rf "$PACKAGE_NAME.xcframework"
xcodebuild -create-xcframework \
    -framework "$PACKAGE_NAME-iphonesimulator.xcarchive/Products/Library/Frameworks/$PACKAGE_NAME.framework" \
    -framework "$PACKAGE_NAME-iphoneos.xcarchive/Products/Library/Frameworks/$PACKAGE_NAME.framework" \
    -output "$PACKAGE_NAME.xcframework"

cp -r "$PACKAGE_NAME-iphonesimulator.xcarchive/dSYMs" "$PACKAGE_NAME.xcframework/ios-arm64_x86_64-simulator"
cp -r "$PACKAGE_NAME-iphoneos.xcarchive/dSYMs" "$PACKAGE_NAME.xcframework/ios-arm64"
