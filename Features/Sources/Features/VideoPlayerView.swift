import SwiftUI
import AVKit
import Combine
import AVFoundation

struct VideoPlayerView: View {
    let url: URL
    @Binding var isPresented: Bool
    @State private var player: AVPlayer
    @State private var cancellables = Set<AnyCancellable>()
    @State private var playerStatus: String = "Initializing..."
    @State private var showDebugInfo = true
    
    init(url: URL, isPresented: Binding<Bool>) {
        self.url = url
        self._isPresented = isPresented
        // Initialize player with URL directly
        self._player = State(initialValue: AVPlayer(url: url))
    }
    
    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onAppear {
                    setupPlayer()
                }
                .onDisappear {
                    player.pause()
                    cancellables.removeAll()
                }
                .overlay(alignment: .topTrailing) {
                    Button(action: { 
                        isPresented = false 
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }
            
            // Debug overlay
            if showDebugInfo {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playerStatus)
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("URL: \(url.lastPathComponent)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        Button("Hide Debug") {
                            showDebugInfo = false
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .padding()
                    
                    Spacer()
                }
            }
        }
    }
    
    private func setupPlayer() {
        print("=== VideoPlayerView Debug ===")
        print("Video URL: \(url)")
        print("URL scheme: \(url.scheme ?? "none")")
        print("URL host: \(url.host ?? "none")")
        print("URL path: \(url.path)")
        playerStatus = "Loading..."
        
        // Configure audio session first
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                print("Configuring audio session...")
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                try AVAudioSession.sharedInstance().setActive(true)
                print("Audio session configured successfully")
            } catch {
                print("Failed to set audio session: \(error)")
                DispatchQueue.main.async {
                    self.playerStatus = "Audio error: \(error.localizedDescription)"
                }
            }
        }
        
        // Since player is already initialized with URL, just configure it
        player.volume = 1.0
        player.isMuted = false
        player.automaticallyWaitsToMinimizeStalling = true
        
        print("Player volume: \(player.volume), Muted: \(player.isMuted)")
        
        // Get current item
        guard let playerItem = player.currentItem else {
            print("ERROR: No current item on player")
            playerStatus = "Error: No video loaded"
            return
        }
        
        // Simple status observation
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .unknown:
                    print("Player item status: Unknown")
                    self.playerStatus = "Loading..."
                case .readyToPlay:
                    print("Player item status: Ready to play")
                    self.playerStatus = "Ready"
                    // Play immediately when ready
                    self.player.play()
                    print("Called play()")
                case .failed:
                    print("Player item status: Failed")
                    if let error = playerItem.error {
                        print("Error: \(error)")
                        self.playerStatus = "Error: \(error.localizedDescription)"
                    }
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Monitor playback
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .paused:
                    print("Playback: Paused")
                case .waitingToPlayAtSpecifiedRate:
                    print("Playback: Waiting...")
                    if let reason = self.player.reasonForWaitingToPlay {
                        print("Reason: \(reason)")
                        self.playerStatus = "Buffering..."
                    }
                case .playing:
                    print("Playback: Playing")
                    self.playerStatus = "Playing"
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Simple error monitoring
        NotificationCenter.default.publisher(for: .AVPlayerItemNewErrorLogEntry, object: playerItem)
            .sink { _ in
                if let errorLog = playerItem.errorLog() {
                    for event in errorLog.events {
                        print("Error: \(event.errorComment ?? "Unknown")")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
}
