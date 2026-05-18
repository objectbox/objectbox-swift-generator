# ObjectBox Swift Generator changelog

## 2.3.0

- Support `syncClock` and `syncPrecedence` annotations.

## 2.2.0

- Support string vectors (`[String]`).
- Support integer vectors (`[Int32]` and `[Int64]`).
- Integrate changes up to Sourcery 2.3.0. Notably supports building the generator with Xcode 26.

## 2.1.3

- In model JSON files, change key order to match other generators. This will make it easier to compare model files.

## 2.1.2

- To prepare for Swift 6 language mode and data race safety, make generated entity info and binding immutable.

## 2.1.1

- Support Xcode 16 projects that use groups as well as buildable folders.

## 2.1.0

- Support `externalType` and `externalName` annotations.

## 2.0.0

- Integrate changes up to Sourcery 2.2.6.
- Support Xcode 16 projects with buildable folders.

## 1.2.0

- Support `geo` distance type in HNSW annotation.

## Older releases

There are currently no notes for older releases.
