#!/bin/bash

#  RunToolTests.sh
#  Sourcery
#
#  Created by Uli Kusterer on 07.12.18.
#  

echo "note: Starting tests..."
cd ${BUILT_PRODUCTS_DIR}

SOURCERY="${BUILT_PRODUCTS_DIR}/Sourcery.app/Contents/MacOS/Sourcery"
TESTPROJECT="${PROJECT_DIR}/ObjectBoxToolTests/ToolTestProject.xcodeproj"
TESTMODELFILE="${BUILT_PRODUCTS_DIR}/model1.json"
OUTPUTFILE="${BUILT_PRODUCTS_DIR}/"

$SOURCERY --xcode-project "$TESTPROJECT" --xcode-target ToolTestProject --model-json "$TESTMODELFILE" --output "$OUTPUTFILE"

rm "$TESTMODELFILE"
rm "$OUTPUTFILE"

echo "note: Finished tests..."
