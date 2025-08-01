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
    @State private var showDebugInfo = false
    
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
                            .background(DesignSystem.Colors.backgroundPrimary.opacity(DesignSystem.Opacity.semiVisible))
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
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(DesignSystem.Spacing.xxSmall)
                        .background(DesignSystem.Colors.backgroundPrimary.opacity(0.7))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        Button("Hide Debug") {
                            showDebugInfo = false
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(DesignSystem.Spacing.xxSmall)
                        .background(DesignSystem.Colors.backgroundPrimary.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .padding()
                    
                    Spacer()
                }
            }
        }
    }
    
    private func setupPlayer() {
        #if DEBUG
        print("=== VideoPlayerView Debug ===")
        print("Video URL: \(url)")
        print("URL scheme: \(url.scheme ?? "none")")
        print("URL host: \(url.host ?? "none")")
        print("URL path: \(url.path)")
        #endif
        playerStatus = "Loading..."
        
        // Configure audio session first
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                #if DEBUG
                print("Configuring audio session...")
                #endif
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                try AVAudioSession.sharedInstance().setActive(true)
                #if DEBUG
                print("Audio session configured successfully")
                #endif
            } catch {
                #if DEBUG
                print("Failed to set audio session: \(error)")
                #endif
                DispatchQueue.main.async {
                    self.playerStatus = "Audio error: \(error.localizedDescription)"
                }
            }
        }
        
        // Since player is already initialized with URL, just configure it
        player.volume = 1.0
        player.isMuted = false
        player.automaticallyWaitsToMinimizeStalling = true
        
        #if DEBUG
        print("Player volume: \(player.volume), Muted: \(player.isMuted)")
        #endif
        
        // Get current item
        guard let playerItem = player.currentItem else {
            #if DEBUG
            print("ERROR: No current item on player")
            #endif
            playerStatus = "Error: No video loaded"
            return
        }
        
        // Simple status observation
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .unknown:
                    #if DEBUG
                    print("Player item status: Unknown")
                    #endif
                    self.playerStatus = "Loading..."
                case .readyToPlay:
                    #if DEBUG
                    print("Player item status: Ready to play")
                    #endif
                    self.playerStatus = "Ready"
                    // Play immediately when ready
                    self.player.play()
                    #if DEBUG
                    print("Called play()")
                    #endif
                case .failed:
                    #if DEBUG
                    print("Player item status: Failed")
                    #endif
                    if let error = playerItem.error {
                        #if DEBUG
                        print("Error: \(error)")
                        #endif
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
                    #if DEBUG
                    print("Playback: Paused")
                    #endif
                case .waitingToPlayAtSpecifiedRate:
                    #if DEBUG
                    print("Playback: Waiting...")
                    #endif
                    if let reason = self.player.reasonForWaitingToPlay {
                        #if DEBUG
                        print("Reason: \(reason)")
                        #endif
                        self.playerStatus = "Buffering..."
                    }
                case .playing:
                    #if DEBUG
                    print("Playback: Playing")
                    #endif
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
                        #if DEBUG
                        print("Error: \(event.errorComment ?? "Unknown")")
                        #endif
                    }
                }
            }
            .store(in: &cancellables)
    }
    
}
