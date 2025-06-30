//  RootView.swift     (Features)

import SwiftUI
import Infrastructure          // for AuthStore
import DomainLogic             // for CaptureViewModel

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

    public init(auth: AuthBridge, captureVM: CaptureViewModel) {
        self.auth = auth
        self.captureVM = captureVM
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
            ContentView(viewModel: captureVM)
                .environmentObject(auth)
        }
    }
}

struct SignInView: UIViewControllerRepresentable {
    @ObservedObject var auth: AuthBridge

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        host.view.backgroundColor = .systemBackground

        // a single button centred on the screen
        let button = UIButton(type: .system, primaryAction:
            UIAction(title: "Sign in with Google") { _ in
                Task { await auth.signIn(presenting: host) }
            })
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: host.view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: host.view.centerYAnchor)
        ])
        return host
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}
