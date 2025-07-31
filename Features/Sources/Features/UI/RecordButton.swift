//
//  RecordButton.swift
//  Features
//
//  Custom Voice Memos-style record button with morphing animation
//

import SwiftUI
import AVFoundation

/// Custom Voice Memos-style record button that morphs between circle and rounded square
public struct RecordButton: View {
    // MARK: - Properties
    
    /// Whether recording is currently active
    let isRecording: Bool
    
    /// Action to perform when button is tapped
    let action: () -> Void
    
    /// Button size (80-100pt as per spec)
    private let size: CGFloat = 88
    
    /// Corner radius for morphing animation
    private var cornerRadius: CGFloat {
        isRecording ? 15 : size / 2
    }
    
    /// Icon to display
    private var iconName: String {
        isRecording ? "stop.fill" : "mic.fill"
    }
    
    /// Scale effect for press feedback
    @State private var isPressed = false
    
    // MARK: - Body
    
    public var body: some View {
        Button(action: handleTap) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DesignSystem.Colors.cardBackground)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(DesignSystem.Colors.cardBorder, lineWidth: 2)
                )
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
        .accessibilityHint(isRecording ? "Double tap to stop recording your dream" : "Double tap to start recording your dream")
        .animation(.easeInOut(duration: 0.08), value: isRecording)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }
    
    // MARK: - Private Methods
    
    private func handleTap() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Audio feedback
        playAudioFeedback()
        
        // Perform action
        action()
    }
    
    private func playAudioFeedback() {
        // Play system sounds for start/stop recording
        // Using system sounds as specified in the plan
        if isRecording {
            // Stop recording sound
            AudioServicesPlaySystemSound(1075) // Tock sound
        } else {
            // Start recording sound
            AudioServicesPlaySystemSound(1113) // Begin recording sound
        }
    }
    
    // MARK: - Public Init
    
    public init(isRecording: Bool, action: @escaping () -> Void) {
        self.isRecording = isRecording
        self.action = action
    }
}

// MARK: - Preview

#if DEBUG
struct RecordButton_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var isRecording = false
        
        var body: some View {
            VStack(spacing: 40) {
                RecordButton(isRecording: isRecording) {
                    isRecording.toggle()
                }
                
                Text(isRecording ? "Recording..." : "Tap to start")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .previewDisplayName("Record Button")
    }
}
#endif