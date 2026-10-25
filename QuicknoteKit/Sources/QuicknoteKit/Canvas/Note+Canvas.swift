import Foundation

extension Note {
    /// The Snap or Card design stored in `canvasJSON`. A value that cannot be decoded reads as nil.
    public var canvas: CanvasDocument? {
        get { canvasJSON.flatMap { try? JSONDecoder().decode(CanvasDocument.self, from: Data($0.utf8)) } }
        set {
            canvasJSON = newValue.flatMap { try? JSONEncoder().encode($0) }.flatMap {
                String(data: $0, encoding: .utf8)
            }
        }
    }
}
