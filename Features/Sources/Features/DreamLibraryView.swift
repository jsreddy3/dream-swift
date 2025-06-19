import CoreModels
import Infrastructure
import DomainLogic
import Foundation
import SwiftUI

struct DreamLibraryView: View {
    @State private var vm: DreamLibraryViewModel
    @State private var open: UUID? = nil           // which dream is expanded
    @State private var clips: [UUID: [AudioSegment]] = [:]

    init(viewModel: DreamLibraryViewModel) {
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        List(vm.dreams) { dream in
            DisclosureGroup(isExpanded: Binding(
                get: { open == dream.id },
                set: { expanded in
                    open = expanded ? dream.id : nil
                    if expanded && clips[dream.id] == nil {
                        Task {
                            clips[dream.id] = try? await vm.segments(for: dream)
                        }
                    }
                })) {
                if let segs = clips[dream.id] {
                    ForEach(segs, id: \.id) { seg in
                        Text("Clip \(seg.order) – \(Int(seg.duration)) s")
                    }
                } else {
                    ProgressView()
                }
            } label: {
                HStack {
                    Text(dream.title.isEmpty ? "Untitled" : dream.title)
                    Spacer()
                    Text(dream.state == .draft ? "Draft" : "Done")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .task { vm.refresh() }
        .navigationTitle("Dream Library")
    }
}
