import WidgetKit
import SwiftUI

@main
struct DreamWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickRecordWidget()          // <- that’s the ONLY widget now
    }
}
