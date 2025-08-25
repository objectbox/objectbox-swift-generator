# ObjectBox Swift Generator

This is a fork of [sourcery](https://github.com/krzysztofzablocki/Sourcery/) modified to be used as the ObjectBox Swift
model file and code generator for the ObjectBox Swift SDK.

See the [Getting Started](https://swift.objectbox.io/getting-started) page on how to use the ObjectBox Swift SDK.

## Development

This is a Swift Package.

Recent changes are documented in the [changelog](/CHANGELOG.md).

[SwiftLint](https://github.com/realm/SwiftLint) is added using the [SwiftLintPlugins repository](https://github.com/SimplyDanny/SwiftLintPlugins).

Run its command plugin manually using Xcode (right-click the package, select "SwiftLintCommandPlugin") or run the command shown below.

(Note: due to a [bug in Swift 6.1](https://github.com/swiftlang/swift-package-manager/pull/8440) can't use the build plugin.)

```shell
# Build
swift build

# Run swiftlint from the command line
swift package plugin --allow-writing-to-package-directory swiftlint

# Run unit tests
swift test
```

Additional generator tests exist in the Swift SDK repository (look for "CodeGenTests"). They use the release artifact
discussed below.

## Releasing

An application archive for use by the Swift SDK is produced using `_build.command`.
