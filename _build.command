#!/bin/bash

cd "`dirname "$0"`"
MY_DIR="`pwd`"

echo ""
echo "$(tput smso) Build $(tput rmso)"
echo ""

xcodebuild -workspace "${MY_DIR}/Sourcery.xcworkspace" -scheme "Sourcery-Release" -configuration Release -quiet CONFIGURATION_BUILD_DIR="${MY_DIR}/bin/build"

echo ""
echo "$(tput smso) Clean up... $(tput rmso)"
echo ""

rm -rf "${MY_DIR}/bin/Sourcery.app"
rm -rf "${MY_DIR}/bin/"*.dSYM
mv -f "${MY_DIR}/bin/build/Sourcery.app" "${MY_DIR}/bin/"
mv -f "${MY_DIR}/bin/build/"*.dSYM "${MY_DIR}/bin/"
rm -rf "${MY_DIR}/bin/build"

echo ""
echo "$(tput smso; tput setaf 2) Done. $(tput sgr0; tput bel)"
echo ""
