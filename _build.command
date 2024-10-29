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

xcodebuild -workspace "${MY_DIR}/Sourcery.xcworkspace" -scheme "Sourcery-Release" -configuration Release -quiet CONFIGURATION_BUILD_DIR="${MY_DIR}/bin/build"

# The Swift Package Manager requires an artifact bundle, not an app.
# Therefore, create the artifact bundle from the app.
# The name needs to be changed, since the Sourcery is already taken by Sourcery itself.
# The internals can stay unchanged because names are adjusted in the reuqired info.json file.
rm -rf "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle/"
cp -r "${MY_DIR}/bin/build/Sourcery.app/" "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle"
# Fix the version, and add the required info.json to the artifact bundle
OBECTBOX_GENERATOR_VERSION=$(./bin/build/Sourcery.app/Contents/MacOS/Sourcery --version)
echo "GEN: $OBECTBOX_GENERATOR_VERSION"
jq --arg new_version "$OBECTBOX_GENERATOR_VERSION" \
   '.artifacts["objectbox-generator"].version = $new_version' \
   "${MY_DIR}/Resources/info.json" > \
   "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle/info.json"
# Create the zip file we want to deploy
rm -f "${MY_DIR}/bin/ObjectBox.artifactbundle.zip"
( cd "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle" && zip -r --symlinks "${MY_DIR}/bin/ObjectBoxGenerator.artifactbundle.zip" . )
# add the sha256 for the zip file
( cd ${MY_DIR}/bin/ && shasum -a 256 "ObjectBoxGenerator.artifactbundle.zip" > "ObjectBoxGenerator.artifactbundle.zip.sha256" )

if [ "$dirty" = true ] ; then
    echo ""
    echo "$SMSO Copying (without cleaning)... $RMSO"
    echo ""

    rm -rf "${MY_DIR}/bin/Sourcery.app"
    rm -rf "${MY_DIR}/bin/"*.dSYM
    cp -Rf "${MY_DIR}/bin/build/Sourcery.app" "${MY_DIR}/bin/"
    cp -Rf "${MY_DIR}/bin/build/"*.dSYM "${MY_DIR}/bin/"
else
    echo ""
    echo "$SMSO Clean up... $RMSO"
    echo ""

    rm -rf "${MY_DIR}/bin/Sourcery.app"
    rm -rf "${MY_DIR}/bin/"*.dSYM
    mv -f "${MY_DIR}/bin/build/Sourcery.app" "${MY_DIR}/bin/"
    mv -f "${MY_DIR}/bin/build/"*.dSYM "${MY_DIR}/bin/"
    rm -rf "${MY_DIR}/bin/build"
fi

echo ""
echo "$GREEN Done. $RMGREEN$BEL"
echo ""
