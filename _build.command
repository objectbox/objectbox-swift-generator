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

BUILD_DIR="${MY_DIR}/build/"

# Build using swift build in release configuration
# swift build --disable-sandbox -c release --arch arm64 --build-path $BUILD_DIR
swift build --disable-sandbox -c release --arch x86_64 --build-path $BUILD_DIR
# Create directories if they don't exist
mkdir -p "${MY_DIR}/bin/build"

# Copy the built executable to the build directory
# Swift build places the binary in .build/release/Sourcery
cp -f "${MY_DIR}/build/x86_64-apple-macosx/release/Sourcery" "${MY_DIR}/bin/build/"

# Create a simple app structure to maintain compatibility with the rest of the script
mkdir -p "${MY_DIR}/bin/build/Sourcery.app/Contents/MacOS"
cp -f "${MY_DIR}/build/x86_64-apple-macosx/release/Sourcery" "${MY_DIR}/bin/build/Sourcery.app/Contents/MacOS/"

# The Swift Package Manager requires an artifact bundle, not an app.
# Therefore, create the artifact bundle from the app.
# The name needs to be changed, since the Sourcery is already taken by Sourcery itself.
# The internals can stay unchanged because names are adjusted in the required info.json file.
rm -rf "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle/"
mkdir -p "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle/Contents/MacOS"
cp -f "${MY_DIR}/bin/build/Sourcery.app/Contents/MacOS/Sourcery" "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle/Contents/MacOS/"

# Fix the version, and add the required info.json to the artifact bundle
OBECTBOX_GENERATOR_VERSION=$(${MY_DIR}/bin/build/Sourcery.app/Contents/MacOS/Sourcery --version)
echo "GEN: $OBECTBOX_GENERATOR_VERSION"
jq --arg new_version "$OBECTBOX_GENERATOR_VERSION" \
   '.artifacts["objectbox-generator"].version = $new_version' \
   "${MY_DIR}/Resources/info.json" > \
   "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle/info.json"
   
# Create the zip file we want to deploy
rm -f "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle.zip"
( cd "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle" && zip -r --symlinks "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle.zip" . )
# add the sha256 for the zip file
( cd ${MY_DIR}/bin/ && shasum -a 256 "ObjectBoxGenerator.artifactbundle.zip" > "ObjectBoxGenerator.artifactbundle.zip.sha256" )

if [ "$dirty" = true ] ; then
    echo ""
    echo "$SMSO Copying (without cleaning)... $RMSO"
    echo ""

    rm -rf "${MY_DIR}/bin/Sourcery"
    cp -f "${MY_DIR}/bin/build/Sourcery.app/Contents/MacOS/Sourcery" "${MY_DIR}/bin/"
else
    echo ""
    echo "$SMSO Clean up... $RMSO"
    echo ""

    rm -rf "${MY_DIR}/bin/Sourcery"
    mv -f "${MY_DIR}/bin/build/Sourcery.app/Contents/MacOS/Sourcery" "${MY_DIR}/bin/"
    rm -rf "${MY_DIR}/bin/build"
fi

echo ""
echo "$GREEN Done. $RMGREEN$BEL"
echo ""