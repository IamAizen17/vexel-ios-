import SwiftUI

extension AnyTransition {
    static let vexelPanel = AnyTransition.move(edge: .bottom)
        .combined(with: .opacity)
        .combined(with: .scale(scale: 0.985))
}
