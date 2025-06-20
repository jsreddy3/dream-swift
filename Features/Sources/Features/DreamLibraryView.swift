import CoreModels
import Infrastructure
import DomainLogic
import Foundation
import SwiftUI
struct DreamLibraryView: View {
    @State private var vm: DreamLibraryViewModel
    @State private var open: UUID? = nil                 // restore
    @State private var clips: [UUID: [AudioSegment]] = [:]
    @State private var editing: Dream? = nil
    @State private var draft = ""

    init(viewModel: DreamLibraryViewModel) {
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        List(vm.dreams) { dream in
            // ――― helpers so each closure is tiny ―――
            let isExpanded = Binding(
                get: { open == dream.id && editing == nil },
                set: { expanded in
                    open = expanded ? dream.id : nil
                    if expanded && clips[dream.id] == nil {
                        Task { clips[dream.id] = try? await vm.segments(for: dream) }
                    }
                })

            let clipList = Group {
                if let segs = clips[dream.id] {
                    ForEach(segs, id: \.id) {
                        Text("Clip \($0.order) – \(Int($0.duration)) s")
                    }
                } else { ProgressView() }
            }

            let rowLabel = HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dream.title.isEmpty ? "Untitled" : dream.title)
                        .fontWeight(.semibold)

                    if let t = dream.transcript, !t.isEmpty {
                        Text(t)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)                     // truncate long transcripts
                    }
                }

                Spacer(minLength: 12)

                Text(dream.state == .draft ? "Draft" : "Done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }


            DisclosureGroup(isExpanded: isExpanded) { clipList } label: { rowLabel }
                .swipeActions {
                    Button("Rename") {
                        draft   = dream.title
                        editing = dream
                    }
                }
        }
        .task { await vm.refresh() }
        .navigationTitle("Dream Library")
        // ――― rename sheet ―――
        .sheet(item: $editing) { dream in
            NavigationStack {
                Form {
                    TextField("Title", text: $draft)
                    Button("Save") {
                        Task { await vm.rename(dream, to: draft) }   // ← correct helper
                        editing = nil
                    }
                }
                .navigationTitle("Rename Dream")
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editing = nil }
                }}
            }
        }
    }
}
