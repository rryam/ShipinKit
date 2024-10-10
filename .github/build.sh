#!/bin/bash
set -euo pipefail

# Enable debug output
set -x

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
PROJECT_BUILD_DIR="${PROJECT_ROOT}/build"
SCHEME="RunveyKit"

echo "Current directory: $(pwd)"
echo "Swift version:"
swift --version

# Function to build framework
build_framework() {
    local sdk="$1"
    local destination="$2"
    local archive_path="${PROJECT_BUILD_DIR}/${SCHEME}-${sdk}.xcarchive"
    
    echo "Building for ${sdk}..."
    mkdir -p "${PROJECT_BUILD_DIR}"
    
    # Clean previous archive if exists
    rm -rf "${archive_path}"
    
    echo "Running xcodebuild..."
    xcodebuild archive \
        -scheme "${SCHEME}" \
        -archivePath "${archive_path}" \
        -sdk "${sdk}" \
        -destination "${destination}" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        BUILD_DIR="${PROJECT_BUILD_DIR}/build" \
        OBJROOT="${PROJECT_BUILD_DIR}/build" \
        SYMROOT="${PROJECT_BUILD_DIR}/build" \
        | tee "${PROJECT_BUILD_DIR}/xcodebuild-${sdk}.log" | xcpretty || {
            echo "xcodebuild failed. Full log:"
            cat "${PROJECT_BUILD_DIR}/xcodebuild-${sdk}.log"
            exit 1
        }
    
    # Verify archive was created
    if [ ! -d "${archive_path}" ]; then
        echo "Error: Archive not created at ${archive_path}"
        exit 1
    fi
    
    # Verify framework exists in archive
    if [ ! -d "${archive_path}/Products/Library/Frameworks/${SCHEME}.framework" ]; then
        echo "Error: Framework not found in archive"
        ls -la "${archive_path}/Products/Library/Frameworks" || true
        exit 1
    fi
}

main() {
    # Build for different architectures
    build_framework "iphoneos" "generic/platform=iOS"
    build_framework "iphonesimulator" "generic/platform=iOS Simulator"
    
    # Create XCFramework
    echo "Creating XCFramework..."
    rm -rf "${SCHEME}.xcframework"
    
    xcodebuild -create-xcframework \
        -framework "${PROJECT_BUILD_DIR}/${SCHEME}-iphonesimulator.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
        -framework "${PROJECT_BUILD_DIR}/${SCHEME}-iphoneos.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
        -output "${SCHEME}.xcframework"
    
    # Verify XCFramework was created
    if [ ! -d "${SCHEME}.xcframework" ]; then
        echo "Error: XCFramework not created"
        exit 1
    fi
    
    echo "Build completed successfully."
}

main "$@"
