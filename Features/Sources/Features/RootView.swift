//  RootView.swift     (Features)

import SwiftUI
import Infrastructure          // for AuthStore
import DomainLogic             // for CaptureViewModel

@MainActor                     // safe because it only talks to SwiftUI
public final class AuthBridge: ObservableObject {
    private let backend: AuthStore
    @Published var jwt: String?          // UI can react to this

    public init(_ backend: AuthStore) {
        self.backend = backend
        jwt = backend.jwt                // whatever is in the key-chain

        // poll once a second so changes written by the actor propagate
        Task {
            for await _ in Timer.publish(every: 1,
                                          on: .main,
                                         in: .common).autoconnect().values {
                jwt = backend.jwt
            }
        }
    }

    func signIn(presenting vc: UIViewController) async {
        do { try await backend.signIn(from: vc) }
        catch { print("Google sign-in failed: \(error)") }
        jwt = backend.jwt
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
        Group {
            if auth.jwt == nil {
                SignInView(auth: auth)
            } else {
                ContentView(viewModel: captureVM).environmentObject(auth)
            }
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
