#!/bin/bash
set -e

# macOS does not have realpath and readlink does not have -f option, so do this instead:
MY_DIR=$( cd "$(dirname "$0")" ; pwd -P )
cd "$MY_DIR"

if [ "$TERM" == "" ]; then
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

echo ""
echo "$SMSO Clean up... $RMSO"
echo ""

rm -rf "${MY_DIR}/bin/Sourcery.app"
rm -rf "${MY_DIR}/bin/"*.dSYM
mv -f "${MY_DIR}/bin/build/Sourcery.app" "${MY_DIR}/bin/"
mv -f "${MY_DIR}/bin/build/"*.dSYM "${MY_DIR}/bin/"
rm -rf "${MY_DIR}/bin/build"

echo ""
echo "$GREEN Done. $RMGREEN$BEL"
echo ""
