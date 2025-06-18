import SwiftUI
import Infrastructure       // concrete actors
import DomainLogic

public struct ContentView: View {
    @StateObject private var vm: CaptureViewModel

    public init(viewModel: CaptureViewModel) {          // 🎯 explicit injection
        _vm = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 24) {
            Text(vm.statusText)
                .font(.headline)

            Button(action: {
                vm.isRecording ? vm.stop() : vm.start()
            }) {
                Image(systemName: vm.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .resizable()
                    .frame(width: 88, height: 88)
                    .foregroundStyle(vm.isRecording ? .red : .accentColor)
            }
            .buttonStyle(.plain)

            if vm.hasOpenDream && !vm.isRecording {
                Button("Done") { vm.done() }
                    .font(.title3)
            }
        }
        .padding()
    }
}
