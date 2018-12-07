//
//  main.swift
//  Sourcery
//
//  Created by Krzysztof Zablocki on 09/12/2016.
//  Copyright © 2016 Pixle. All rights reserved.
//

import Foundation
import Commander
import PathKit
import SourceryRuntime
import SourceryJS

extension Path: ArgumentConvertible {
    /// :nodoc:
    public init(parser: ArgumentParser) throws {
        if let path = parser.shift() {
            self.init(path)
        } else {
            throw ArgumentError.missingValue(argument: nil)
        }
    }
}

private enum Validators {
    static func isReadable(path: Path) -> Path {
        if !path.isReadable {
            Log.error("'\(path)' does not exist or is not readable.")
            exit(.invalidePath)
        }

        return path
    }

    static func isFileOrDirectory(path: Path) -> Path {
        _ = isReadable(path: path)

        if !(path.isDirectory || path.isFile) {
            Log.error("'\(path)' isn't a directory or proper file.")
            exit(.invalidePath)
        }

        return path
    }

    static func isWritable(path: Path) -> Path {
        if path.exists && !path.isWritable {
            Log.error("'\(path)' isn't writable.")
            exit(.invalidePath)
        }
        return path
    }
}

extension Configuration {

    func validate() {
        guard !source.isEmpty else {
            Log.error("No sources provided.")
            exit(.invalidConfig)
        }
        if case let .sources(sources) = source {
            _ = sources.allPaths.map(Validators.isReadable(path:))
        }
        _ = templates.allPaths.map(Validators.isReadable(path:))
        guard !templates.isEmpty else {
            Log.error("No templates provided.")
            exit(.invalidConfig)
        }
        _ = output.path.map(Validators.isWritable(path:))
    }

}

enum ExitCode: Int32 {
    case invalidePath = 1
    case invalidConfig
    case other
}

private func exit(_ code: ExitCode) -> Never {
    exit(code.rawValue)
}

func runCLI() {
    command(
        Flag("debug-parsetree", flag: "d", description: "Dump debug output useful in testing the code generator to schemaDump.txt in the current directory."),
        Flag("disableCache", description: "Don't use a cache."),
        Flag("verbose", flag: "v", description: "Turn on verbose logging"),
        Flag("quiet", flag: "q", description: "Turn off any logging, only emit errors."),
        Flag("prune", flag: "p", description: "Remove empty generated files"),
        VariadicOption<Path>("sources", description: "Path to swift source files. File or Directory."),
        VariadicOption<Path>("exclude-sources", description: "Path to swift source files to exclude. File or Directory."),
        VariadicOption<Path>("templates", description: "Path to templates. File or Directory."),
        VariadicOption<Path>("exclude-templates", description: "Path to templates to exclude. File or Directory."),
        Option<Path>("output", "", description: "Path to output. File or Directory. Default is <project parent>/generated/<templateName>.generated.swift or if operating on sources, current path."),
        Option<Path>("xcode-project", "", description: "Path to Xcode project file that contains your entities."),
        Option<String>("xcode-target", "", description: "The target in our Xcode project to scan the source files of."),
        Option<String>("xcode-module", "", description: "The Swift module for this project."),
        VariadicOption<String>("args", description: "Custom values to pass to templates."),
        Option<Path>("model-json", "", description: "Path to JSON file containing model IDs."),
        Option<String>("annotation-prefix", "", description: "Prefix to use for annotations. Defaults to \"objectbox\".")
    ) { debugParseTree, disableCache, verboseLogging, quiet, prune, sources, excludeSources, templates, excludeTemplates, output, projectPath, targetName, moduleName, args, modelJsonPath, annotationPrefix in
        do {
            Log.level = verboseLogging ? .verbose : quiet ? .errors : .info

            ObjectBoxFilters.debugDumpParseData = debugParseTree

            let watcherEnabled = false
            let forceParse: [String] = []

            AnnotationsParser.annotationPrefix = annotationPrefix.isEmpty ? "objectbox" : annotationPrefix
            ObjectBoxFilters.modelJsonFile = modelJsonPath.string.isEmpty ? nil : URL(fileURLWithPath: modelJsonPath.string)

            EJSTemplate.ejsPath = Path(ProcessInfo.processInfo.arguments[0]).parent() + "ejs.js"

            let actualTemplates: [Path]
            if templates.isEmpty, let stencilPath = Bundle.main.path(forResource: "EntityInfo", ofType: "stencil") {
                actualTemplates = [Path(stencilPath)]
            } else {
                actualTemplates = templates
            }

            let configuration: Configuration

            if projectPath.exists {
                if ObjectBoxFilters.modelJsonFile == nil {
                    ObjectBoxFilters.modelJsonFile = projectPath.parent().absolute().url.appendingPathComponent("model.json")
                }

                let args = args.joined(separator: ",")
                let arguments = AnnotationsParser.parse(line: args)
                let theProject = try Project(dict: ["file": projectPath.string, "target": ["name": targetName], "module": moduleName], relativePath: projectPath.parent())
                configuration = Configuration(projects: [theProject],
                                              templates: Paths(include: actualTemplates, exclude: excludeTemplates),
                                              output: output.string.isEmpty ? (projectPath.parent() + Path("generated")) : output,
                                              cacheBasePath: Path.defaultBaseCachePath,
                                              forceParse: forceParse,
                                              args: arguments)
            } else {
                let args = args.joined(separator: ",")
                let arguments = AnnotationsParser.parse(line: args)
                configuration = Configuration(sources: Paths(include: sources, exclude: excludeSources) ,
                                              templates: Paths(include: actualTemplates, exclude: excludeTemplates),
                                              output: output.string.isEmpty ? "." : output,
                                              cacheBasePath: Path.defaultBaseCachePath,
                                              forceParse: forceParse,
                                              args: arguments)
            }

            configuration.validate()

            let start = CFAbsoluteTimeGetCurrent()
            let sourcery = Sourcery(verbose: verboseLogging,
                                    watcherEnabled: watcherEnabled,
                                    cacheDisabled: disableCache,
                                    cacheBasePath: configuration.cacheBasePath,
                                    prune: prune,
                                    arguments: configuration.args)
            if let keepAlive = try sourcery.processFiles(
                configuration.source,
                usingTemplates: configuration.templates,
                output: configuration.output,
                forceParse: configuration.forceParse) {
                RunLoop.current.run()
                _ = keepAlive
            } else {
                Log.info("Processing time \(CFAbsoluteTimeGetCurrent() - start) seconds")
            }
        } catch {
            ObjectBoxFilters.printError(error)
            exit(.other)
        }
        }.run(Sourcery.version)
}

var inUnitTests = NSClassFromString("XCTest") != nil

#if os(macOS)
import AppKit

if !inUnitTests {
    runCLI()
} else {
    //! Need to run something for tests to work
    final class TestApplicationController: NSObject, NSApplicationDelegate {
        let window =   NSWindow()

        func applicationDidFinishLaunching(aNotification: NSNotification) {
            window.setFrame(CGRect(x: 0, y: 0, width: 0, height: 0), display: false)
            window.makeKeyAndOrderFront(self)
        }

        func applicationWillTerminate(aNotification: NSNotification) {
        }

    }

    autoreleasepool { () -> Void in
        let app =   NSApplication.shared
        let controller =   TestApplicationController()

        app.delegate   = controller
        app.run()
    }
}
#endif
