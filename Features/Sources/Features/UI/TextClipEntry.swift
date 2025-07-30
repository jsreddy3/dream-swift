import SwiftUI

struct TextClipEntry: View {
    @Binding var text: String
    var disabled: Bool
    @FocusState.Binding var isFocused: Bool   // NEW
    var onSave: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Type your dream…", text: $text, axis: .vertical)
                .font(DesignSystem.Typography.defaultFont())
                .disabled(disabled)
                .submitLabel(.done)
                .focused($isFocused)          // ← NEW
                .onSubmit { if !disabled { onSave() } }

            Button { onSave() } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
            }
            .buttonStyle(.plain)
            .disabled(disabled ||
                      text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .frame(minWidth: 88, idealWidth: 240, maxWidth: 260)
    }
}
