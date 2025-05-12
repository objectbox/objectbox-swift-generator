# ObjectBox Swift Generator

This is a fork of [sourcery](https://github.com/krzysztofzablocki/Sourcery/) modified to be used as the ObjectBox Swift
model file and code generator for the ObjectBox Swift SDK.

See the [Getting Started](https://swift.objectbox.io/getting-started) page on how to use the ObjectBox Swift SDK.

## Development

This is a Swift Package.

Recent changes are documented in the [changelog](/CHANGELOG.md).

[SwiftLint](https://github.com/realm/SwiftLint) is added as a build tool plugin (it runs as part of build).

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
