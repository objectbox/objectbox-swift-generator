#!/bin/bash

#  RunToolTests.sh
#  Sourcery
#
#  Created by Uli Kusterer on 07.12.18.
#  

echo -n "note: Starting tests at "
date

SOURCERY="${BUILT_PRODUCTS_DIR}/Sourcery.app/Contents/MacOS/Sourcery"
TESTPROJECT="${PROJECT_DIR}/ObjectBoxToolTests/ToolTestProject.xcodeproj"
MYOUTPUTDIR="${PROJECT_DIR}/ObjectBoxToolTests/generated/"
MYOUTPUTFILE="${MYOUTPUTDIR}/EntityInfo.generated.swift"

cd ${BUILT_PRODUCTS_DIR}

test_target_num () {
    FAIL=0

    ORIGINALMODELFILE="${PROJECT_DIR}/ObjectBoxToolTests/model${2}.json"
    TESTMODELFILE="${BUILT_PRODUCTS_DIR}/model${2}.json"
    cp "$ORIGINALMODELFILE" "$TESTMODELFILE"

    echo "// Ensure there's no leftover code from previous tests." > "$MYOUTPUTFILE"

    echo "$SOURCERY --xcode-project \"$TESTPROJECT\" --xcode-target \"ToolTestProject${2}\" --model-json \"$TESTMODELFILE\" --debug-parsetree --output \"$MYOUTPUTDIR\""
    $SOURCERY --xcode-project "$TESTPROJECT" --xcode-target "ToolTestProject${2}" --model-json "$TESTMODELFILE" --debug-parsetree --output "$MYOUTPUTDIR"

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

    ORIGINALSOURCEFILE="${PROJECT_DIR}/ObjectBoxToolTests/EntityInfo.generated${2}.swift"
    cmp --silent "$MYOUTPUTFILE" "$ORIGINALSOURCEFILE"
    if [ $? -eq 0 ]; then
        echo "note: $1: Output files match."
    else
        echo "error: $1: Output files DIFFERENT!"

        echo "===== test: ====="
        cat "$MYOUTPUTFILE"
        echo "===== original: ====="
        cat "$ORIGINALSOURCEFILE"
        echo "====="
        FAIL=1
    fi

    ORIGINALDUMPFILE="${PROJECT_DIR}/ObjectBoxToolTests/schemaDump${2}.txt"
    TESTDUMPFILE="schemaDump.txt"
    cmp --silent "$TESTDUMPFILE" "$ORIGINALDUMPFILE"
    if [ $? -eq 0 ]; then
        echo "note: $1: Schema dumps match."
    else
        echo "error: $1: Schema dumps DIFFERENT!"

        echo "===== test: ====="
        cat "$TESTDUMPFILE"
        echo "===== original: ====="
        cat "$ORIGINALDUMPFILE"
        echo "====="
        FAIL=1
    fi

    if [ $FAIL -eq 0 ]; then
        xcodebuild -project "$TESTPROJECT" -target "ToolTestProject${2}"
        if [ $? -eq 0 ]; then
            echo "note: $1: Built test target."
        else
            echo "error: $1: Build failed."
            FAIL=1
        fi
    else
        echo "error: $1: Skipping build."
    fi

    if [ $FAIL -eq 0 ]; then
        "${BUILT_PRODUCTS_DIR}/ToolTestProject${2}" "${1}"
        if [ $? -eq 0 ]; then
            echo "error: $1: Running test failed."
            FAIL=1
        else
            echo "note: $1: Ran test executable."
        fi
    else
        echo "error: $1: Skipping execution, build already failed."
    fi

    if [ $FAIL == 0 ]; then
        rm "$TESTMODELFILE"
        rm "$MYOUTPUTFILE"
        rm "$TESTDUMPFILE"
    fi

    return $FAIL
}

FAIL=0

test_target_num "Simple Model" 1 || FAIL=1
test_target_num "Subclassed Model" 2 || FAIL=1

echo "note: Finished tests..."

exit $FAIL
