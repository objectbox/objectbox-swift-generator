#!/bin/bash

MY_DIR=`dirname "$0"`

echo "$MY_DIR"

xcodebuild -workspace "${MY_DIR}/Sourcery.xcworkspace" -scheme "Sourcery-Release" -configuration Release CONFIGURATION_BUILD_DIR="${MY_DIR}/bin/build"

rm -rf "${MY_DIR}/bin/Sourcery.app"
rm -rf "${MY_DIR}/bin/"*.dSYM
mv -f "${MY_DIR}/bin/build/Sourcery.app" "${MY_DIR}/bin/"
mv -f "${MY_DIR}/bin/build/"*.dSYM "${MY_DIR}/bin/"
rm -rf "${MY_DIR}/bin/build"