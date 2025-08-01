import SwiftUI
import Foundation

/// Coordinates navigation and actions between tabs
@MainActor
public class TabCoordinator: ObservableObject {
    @Published public var selectedTab: Int = 0
    @Published public var shouldStartRecording: Bool = false
    
    public init() {}
    
    /// Switches to Record tab and optionally starts recording
    public func switchToRecordAndStart() {
        selectedTab = 1 // Record tab
        shouldStartRecording = true
    }
    
    /// Resets the recording trigger
    public func resetRecordingTrigger() {
        shouldStartRecording = false
    }
}