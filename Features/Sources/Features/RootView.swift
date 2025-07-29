//  RootView.swift     (Features)

import SwiftUI
import Infrastructure          // for AuthStore
import DomainLogic             // for CaptureViewModel
import CoreModels              // for shared types

// MARK: - Color Palette
private extension Color {
    static let campfireBg   = Color(red: 33/255, green: 24/255, blue: 21/255)
    static let campfireCard = Color(red: 54/255, green: 37/255, blue: 32/255)
    static let ember        = Color(red: 255/255, green: 145/255, blue: 0/255)
}

@MainActor                     // safe because it only talks to SwiftUI
public final class AuthBridge: ObservableObject {
    private let backend: AuthStore
    @Published var isAuthenticating = false   // ⟵ add this
    @Published var jwt: String?          // UI can react to this

    public init(_ backend: AuthStore) {
        self.backend = backend
        jwt = backend.jwt                // whatever is in the key-chain
    }

    func signIn(presenting vc: UIViewController) async {
        await MainActor.run { isAuthenticating = true }

        // • The defer must not contain ‘await’.
        // • Wrapping the mutation in Task { @MainActor in … } is allowed.
        defer { Task { @MainActor in self.isAuthenticating = false } }

        do {
            try await backend.signIn(from: vc)          // Google + backend
            await MainActor.run { jwt = backend.jwt }   // immediate UI update
        } catch {
            print("Google sign-in failed: \(error)")
        }
    }
    
    @MainActor
    func signOut() {
        Task {                                  // hop off the main thread
            await backend.signOut()
            await MainActor.run { jwt = nil }   // make UI react instantly
        }
    }
}

public struct RootView: View {                      // ← public
    @ObservedObject public var auth: AuthBridge
    public let captureVM: CaptureViewModel
    public let libraryVM: DreamLibraryViewModel

    public init(auth: AuthBridge, captureVM: CaptureViewModel, libraryVM: DreamLibraryViewModel) {
        self.auth = auth
        self.captureVM = captureVM
        self.libraryVM = libraryVM
    }

    public var body: some View {
        if auth.jwt == nil {
            ZStack {                               // keep hierarchy stable
                SignInView(auth: auth)
                    .opacity(auth.isAuthenticating ? 0 : 1)   // ← hide button

                if auth.isAuthenticating {
                    Color.black.opacity(0.2).ignoresSafeArea() // dim background
                    ProgressView("Signing in…")
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        } else {
            ContentView(viewModel: captureVM, libraryViewModel: libraryVM)
                .environmentObject(auth)
        }
    }
}

struct SignInView: View {
    @ObservedObject var auth: AuthBridge
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Campfire video background
            GeometryReader { geometry in
                LoopingVideoView(named: "campfire_fullrange")
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .opacity(0.6)
            }
            .ignoresSafeArea()
            
            // Dark overlay for readability
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Welcome content
                VStack(spacing: 24) {
                    // App title/logo area
                    VStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color.ember)
                        
                        Text("Dream")
                            .font(.custom("Avenir-Heavy", size: 42))
                            .foregroundColor(.white)
                    }
                    
                    // Welcome message
                    VStack(spacing: 16) {
                        Text("Capture the wisdom of your sleep")
                            .font(.custom("Avenir-Medium", size: 24))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Record your dreams the moment you wake,\nand discover their hidden meanings")
                            .font(.custom("Avenir-Book", size: 18))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                
                Spacer()
                
                // Sign in button
                VStack(spacing: 16) {
                    GoogleSignInButton(auth: auth)
                        .padding(.horizontal, 24)
                    
                    Text("Your dreams are private and secure")
                        .font(.custom("Avenir-Book", size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 32)
        }
    }
}

struct GoogleSignInButton: View {
    @ObservedObject var auth: AuthBridge
    
    var body: some View {
        Button {
            // Get the current window's root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                Task { await auth.signIn(presenting: rootViewController) }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .medium))
                
                Text("Continue with Google")
                    .font(.custom("Avenir-Medium", size: 18))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 27)
                    .fill(Color.ember)
            )
        }
        .buttonStyle(.plain)
    }
}
