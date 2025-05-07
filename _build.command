#!/bin/bash
set -e

# macOS does not have realpath and readlink does not have -f option, so do this instead:
MY_DIR=$( cd "$(dirname "$0")" ; pwd -P )
cd "$MY_DIR"

if [ "${1:-}" == "--dirty" ]; then
    dirty=true
    shift
else
    dirty=false
fi

if [ "$TERM" == "" ] || [ "$TERM" == "dumb" ] ; then
    SMSO=""
    RMSO=""
    BEL=""
    GREEN=""
    RMGREEN=""
    GRAY=""
    RMGRAY=""
    RED=""
    RMRED=""
else
    SMSO="$(tput smso)"
    RMSO="$(tput rmso)"
    BEL="$(tput bel)"
    GREEN="$(tput smso; tput setaf 2)"
    RMGREEN="$(tput rmso; tput sgr0)"
    GRAY="$(tput smso; tput setaf 7)"
    RMGRAY="$(tput rmso; tput sgr0)"
    RED="$(tput setaf 9; tput smso)"
    RMRED="$(tput rmso; tput sgr0)"
fi

echo ""
echo "$SMSO Build $RMSO"
echo ""

# Matches the default SwiftPM build directory
BUILD_DIR="${MY_DIR}/.build"

# Directory where Sourcery binary (for testing in Swift repo) and MacOS application archive (for releases) are stored
OUTPUT_DIR="${MY_DIR}/bin"

if [ "$dirty" != true ] ; then
  echo "Cleaning build artifacts"
  swift package clean
fi

# Build using swift build in release configuration
swift build --disable-sandbox -c release --arch arm64 --build-path $BUILD_DIR
swift build --disable-sandbox -c release --arch x86_64 --build-path $BUILD_DIR

echo "Create a bare-minimum macOS app for the Swift library"
# This is included directly in a Carthage and CocoaPods release, and packaged up below in an extra artifact for a
# SwiftPM binary release.
mkdir -p "${OUTPUT_DIR}/Sourcery.app/Contents/MacOS"
mkdir -p "${OUTPUT_DIR}/Sourcery.app/Contents/Resources"
cp "${MY_DIR}/Sourcery/ObjectBox/EntityInfo.stencil" "${OUTPUT_DIR}/Sourcery.app/Contents/Resources/"
cp "${MY_DIR}/SourceryExecutable/Info.plist" "${OUTPUT_DIR}/Sourcery.app/Contents/"

# Create universal binary using lipo
lipo -create \
  "${BUILD_DIR}/arm64-apple-macosx/release/Sourcery" \
  "${BUILD_DIR}/x86_64-apple-macosx/release/Sourcery" \
  -output "${OUTPUT_DIR}/Sourcery.app/Contents/MacOS/Sourcery"

echo "Create an artifact bundle for the Swift library Swift package"
# The Swift Package Manager requires an artifact bundle, not an app.
# Therefore, create the artifact bundle from the app.
# The name needs to be changed, since the Sourcery is already taken by Sourcery itself.
# The internals can stay unchanged because names are adjusted in the required info.json file.
rm -rf "${OUTPUT_DIR}/ObjectBoxGenerator.artifactbundle/"
cp -r "${OUTPUT_DIR}/Sourcery.app" "${OUTPUT_DIR}/ObjectBoxGenerator.artifactbundle"

# Fix the version, and add the required info.json to the artifact bundle
OBECTBOX_GENERATOR_VERSION=$(${OUTPUT_DIR}/Sourcery.app/Contents/MacOS/Sourcery --version)
echo "GEN: $OBECTBOX_GENERATOR_VERSION"
jq --arg new_version "$OBECTBOX_GENERATOR_VERSION" \
   '.artifacts["objectbox-generator"].version = $new_version' \
   "${MY_DIR}/Resources/info.json" > \
   "${OUTPUT_DIR}/ObjectBoxGenerator.artifactbundle/info.json"
   
# Create the zip file we want to deploy
rm -f "${OUTPUT_DIR}/ObjectBoxGenerator.artifactbundle.zip"
( cd "${OUTPUT_DIR}/ObjectBoxGenerator.artifactbundle" && zip -r --symlinks "${OUTPUT_DIR}/ObjectBoxGenerator.artifactbundle.zip" . )
# add the sha256 for the zip file
( cd ${OUTPUT_DIR} && shasum -a 256 "ObjectBoxGenerator.artifactbundle.zip" > "ObjectBoxGenerator.artifactbundle.zip.sha256" )

echo "Copy the Sourcery binary to ${OUTPUT_DIR} for tests in Swift library"
rm -rf "${OUTPUT_DIR}/Sourcery"
cp -f "${OUTPUT_DIR}/Sourcery.app/Contents/MacOS/Sourcery" "${OUTPUT_DIR}"

echo ""
echo "$GREEN Done. $RMGREEN$BEL"
echo ""
