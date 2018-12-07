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

test_target_num () {
    FAIL=0

    ORIGINALMODELFILE="${PROJECT_DIR}/ObjectBoxToolTests/model${3}.json"
    cp "$ORIGINALMODELFILE" "$TESTMODELFILE"

    $SOURCERY --xcode-project "$TESTPROJECT" --xcode-target "$2" --model-json "$TESTMODELFILE" --output "`dirname '$OUTPUTFILE'`"

    cmp --silent "$TESTMODELFILE" "$ORIGINALMODELFILE"
    if [ $? -eq 0 ]; then
        echo "note: $1: Model files match."
    else
        echo "error: $1: Model files DIFFERENT!"

        echo "===== test: ====="
        cat "$TESTMODELFILE"
        echo "===== original: ====="
        cat "$ORIGINALMODELFILE"
        echo "====="
        FAIL=1
    fi

    ORIGINALSOURCEFILE="${PROJECT_DIR}/ObjectBoxToolTests/EntityInfo.generated${3}.swift"
    cmp --silent "$OUTPUTFILE" "$ORIGINALSOURCEFILE"
    if [ $? -eq 0 ]; then
        echo "note: $1: Output files match."
    else
        echo "error: $1: Output files DIFFERENT!"

        echo "===== test: ====="
        cat "$OUTPUTFILE"
        echo "===== original: ====="
        cat "$ORIGINALSOURCEFILE"
        echo "====="
        FAIL=1
    fi

    rm "$TESTMODELFILE"
    rm "$OUTPUTFILE"

    exit $FAIL
}

test_target_num "Simple Model" ToolTestProject 1

echo "note: Finished tests..."
