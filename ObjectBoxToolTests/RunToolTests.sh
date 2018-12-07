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
TESTMODELFILE="${BUILT_PRODUCTS_DIR}/model.json"
OUTPUTFILE="${BUILT_PRODUCTS_DIR}/EntityInfo.generated.swift"

ORIGINALMODELFILE="${PROJECT_DIR}/ObjectBoxToolTests/model1.json"
ORIGINALSOURCEFILE="${PROJECT_DIR}/ObjectBoxToolTests/EntityInfo.generated1.swift"
cp "${PROJECT_DIR}/ObjectBoxToolTests/model1.json" "$TESTMODELFILE"

$SOURCERY --xcode-project "$TESTPROJECT" --xcode-target ToolTestProject --model-json "$TESTMODELFILE" --output "`dirname '$OUTPUTFILE'`"
cmp --silent "$TESTMODELFILE" "$ORIGINALMODELFILE"
if [ $? -eq 0 ]; then
    echo "note: Model files match."
else
    echo "error: Model files DIFFERENT!"
fi

cmp --silent "$OUTPUTFILE" "$ORIGINALSOURCEFILE"
if [ $? -eq 0 ]; then
echo "note: Output files match."
else
echo "error: Output files DIFFERENT!"
fi

rm "$TESTMODELFILE"
rm "$OUTPUTFILE"

echo "note: Finished tests..."
