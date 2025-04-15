import Foundation
import SourceryFramework
import SourceryRuntime
import SourceryStencil

extension StencilTemplate: SourceryFramework.Template {
    public func render(_ context: TemplateContext) throws -> String {
        do {
            var stencilContext = context.stencilContext
            ObjectBoxGenerator.exposeObjects(to: &stencilContext)
            return try self.render(stencilContext)
        } catch {
            throw "\(sourcePath): \(error)"
        }
    }
}
