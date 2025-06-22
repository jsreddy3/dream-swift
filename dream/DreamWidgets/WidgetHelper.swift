import SwiftUI
import WidgetKit

extension View {
    /// Applies `.containerBackground` on iOS 17+ and does nothing on iOS 16.
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            // Choose the system fill that looks best against the Lock-Screen wallpaper
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
        }
    }
}
