import SwiftUI
import CoreModels
import Configuration
import DomainLogic

// MARK: - First Recording Guidance Modal

/// A beautifully designed modal that appears for first-time users to guide them 
/// in effective dream storytelling before their first recording experience
public struct FirstRecordingGuidanceModal: View {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    
    public init(isPresented: Binding<Bool>, onDismiss: @escaping () -> Void) {
        self._isPresented = isPresented
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Simple header
            VStack(spacing: 12) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 32))
                    .foregroundColor(DesignSystem.Colors.ember)
                
                Text("Ready to record your first dream?")
                    .font(DesignSystem.Typography.title2())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            
            // Minimal guidance
            Text("Just speak naturally about what you remember.")
                .font(DesignSystem.Typography.body())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Simple button
            Button(action: dismissModal) {
                Text("Got it")
                    .font(DesignSystem.Typography.bodyMedium())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(DesignSystem.Colors.ember)
                    )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("First recording guidance")
        .accessibilityHint("Tap to dismiss and start recording your first dream")
    }
    
    private func dismissModal() {
        isPresented = false
        onDismiss()
    }
}

// MARK: - Guidance Manager

/// Manages the state and logic for showing the first recording guidance modal
@MainActor
public class FirstRecordingGuidanceManager: ObservableObject {
    @Published public var shouldShowGuidance = false
    
    private let userDefaultsKey = "hasSeenRecordingGuidance"
    
    public init() {}
    
    /// Check if guidance should be shown based on feature flags and user state
    public func checkShouldShowGuidance(dreamStore: DreamStore) async {
        // Always show if debug flag is enabled
        if Config.forceOnboardingDebug {
            shouldShowGuidance = true
            return
        }
        
        // Don't show if user has already seen guidance
        if UserDefaults.standard.bool(forKey: userDefaultsKey) {
            shouldShowGuidance = false
            return
        }
        
        // Show if user has no dreams (first-time experience)
        do {
            let dreams = try await dreamStore.allDreams()
            shouldShowGuidance = dreams.isEmpty
        } catch {
            // If we can't check dreams, err on the side of showing guidance
            shouldShowGuidance = true
        }
    }
    
    /// Mark guidance as seen so it won't show again
    public func markGuidanceAsSeen() {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        shouldShowGuidance = false
    }
    
    /// Reset guidance state (for testing)
    public func resetGuidanceState() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

// MARK: - Preview

#if DEBUG
struct FirstRecordingGuidanceModal_Previews: PreviewProvider {
    static var previews: some View {
        FirstRecordingGuidanceModal(isPresented: .constant(true)) {
            print("Modal dismissed")
        }
        .background(DreamBackground())
    }
}
#endif