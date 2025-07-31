import Foundation

public enum Config {
    /// Base URL of your backend (no trailing slash)
//    public static let apiBase = URL(string: "http://192.168.0.102:8000")!
//    public static let apiBase = URL(string: "http://192.168.1.119:8000")!
    // public static let apiBase = URL(string: "https://backend-dream.fly.dev")!
//     public static let apiBase = URL(string: "http://172.20.10.5:8000")!
//    public static let apiBase = URL(string: "http://172.20.10.2:8000")!
//    public static let apiBase = URL(string: "https://backend-dream.fly.dev")!
//    public static let apiBase = URL(string: "http://192.168.0.16:8000")!
    // public static let apiBase = URL(string: "http://10.80.82.109:8000")!
    public static let apiBase = URL(string: "http://10.80.82.109:8000")!
    
    /// Google OAuth client ID for the iOS bundle
    public static let googleClientID = "291516817801-f96frg6p6qujejfml5b6i7l7bbk4f8ah.apps.googleusercontent.com"
    
    public static let GIDClientId = "291516817801-f96frg6p6qujejfml5b6i7l7bbk4f8ah.apps.googleusercontent.com"
    
    /// JWT lifetime on the server, in hours (keep in sync with backend settings)
    public static let jwtExpiryHours: Int = 12
    
    // MARK: - Feature Flags
    
    /// Force onboarding to show for all users (for testing purposes)
    /// Set to false for production to respect user completion state
    /// Temporarily disabled to prevent startup hanging issues
    public static let forceOnboardingForTesting: Bool = true
    
    // MARK: - Record Page Redesign Feature Flags
    
    /// Enable custom Voice Memos-style record button
    public static let recordPageRedesignCustomButton: Bool = true
    
    /// Enable continuous recording architecture
    public static let recordPageRedesignContinuousRecording: Bool = true
    
    /// Enable waveform visualization
    public static let recordPageRedesignWaveformViz: Bool = false
    
    /// Enable full UI redesign
    public static let recordPageRedesignFullUI: Bool = false
}
