//
//  RecordButtonTestView.swift
//  Features
//
//  Test view for verifying RecordButton functionality
//

import SwiftUI

#if DEBUG
struct RecordButtonTestView: View {
    @State private var isRecording = false
    @State private var animationStartTime: Date?
    @State private var animationDuration: TimeInterval = 0
    @State private var testResults: [String] = []
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Record Button Test")
                .font(.largeTitle)
                .padding(.top)
            
            // Test button
            RecordButton(isRecording: isRecording) {
                // Capture animation timing
                if !isRecording {
                    animationStartTime = Date()
                } else if let startTime = animationStartTime {
                    animationDuration = Date().timeIntervalSince(startTime)
                    testResults.append("Animation duration: \(String(format: "%.3f", animationDuration))s")
                }
                isRecording.toggle()
            }
            
            // Status
            Text(isRecording ? "Recording..." : "Tap to start")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Animation test result
            if animationDuration > 0 {
                HStack {
                    Image(systemName: animationDuration < 0.1 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(animationDuration < 0.1 ? .green : .red)
                    Text("Animation: \(String(format: "%.3f", animationDuration))s")
                        .font(.caption)
                }
            }
            
            // Test results log
            if !testResults.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Test Log:")
                        .font(.headline)
                    ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                        Text("\(index + 1). \(result)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Device info
            VStack(spacing: 5) {
                Text("Device: \(UIDevice.current.name)")
                    .font(.caption)
                Text("Screen: \(Int(UIScreen.main.bounds.width)) x \(Int(UIScreen.main.bounds.height))")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .padding(.top)
            
            Spacer()
            
            // Instructions
            VStack(alignment: .leading, spacing: 10) {
                Text("Testing Checklist:")
                    .font(.headline)
                Text("✓ Morphing animation < 0.1s")
                Text("✓ Haptic feedback on tap")
                Text("✓ Audio feedback sounds")
                Text("✓ VoiceOver labels")
                Text("✓ Visual appearance")
            }
            .font(.caption)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
    }
}

struct RecordButtonTestView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Test on different device sizes
            RecordButtonTestView()
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")
            
            RecordButtonTestView()
                .previewDevice("iPhone 15")
                .previewDisplayName("iPhone 15")
            
            RecordButtonTestView()
                .previewDevice("iPhone 15 Pro Max")
                .previewDisplayName("iPhone 15 Pro Max")
        }
    }
}
#endif