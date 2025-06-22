import WidgetKit
import SwiftUI

// MARK: – trivial timeline
struct QuickRecordEntry: TimelineEntry { let date = Date() }

struct QuickRecordProvider: TimelineProvider {
    func placeholder(in: Context) -> QuickRecordEntry { .init() }
    func getSnapshot(in: Context, completion: @escaping (QuickRecordEntry)->Void) {
        completion(.init())
    }
    func getTimeline(in: Context, completion: @escaping (Timeline<QuickRecordEntry>)->Void) {
        completion(Timeline(entries: [.init()], policy: .never))
    }
}

// MARK: – the widget
struct QuickRecordWidget: Widget {
    let kind = "QuickRecord"

    var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: QuickRecordProvider()) { _ in
                // full-colour rendering mode is fine on the Lock Screen
                Image("DreamBadge")                     // <- your asset name
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .widgetURL(URL(string: "dreamrec://capture?autoStart=1")!)
                    .widgetContainerBackground()
            }
            .supportedFamilies([.accessoryCircular,
                                .accessoryRectangular,
                                .accessoryInline])
        }
}
