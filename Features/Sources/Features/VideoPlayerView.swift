import SwiftUI
import AVKit
import Combine
import AVFoundation

struct VideoPlayerView: View {
    let url: URL
    @Binding var isPresented: Bool
    @State private var player: AVPlayer
    @State private var cancellables = Set<AnyCancellable>()
    
    init(url: URL, isPresented: Binding<Bool>) {
        self.url = url
        self._isPresented = isPresented
        self._player = State(initialValue: AVPlayer(url: url))
    }
    
    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .onAppear {
                // Configure audio session for playback
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("Failed to set audio session: \(error)")
                }
                
                // Ensure volume is up
                player.volume = 1.0
                player.isMuted = false
                
                // Debug audio tracks
                if let currentItem = player.currentItem {
                    let audioTracks = currentItem.tracks.filter { $0.assetTrack?.mediaType == .audio }
                    print("Audio tracks found: \(audioTracks.count)")
                    audioTracks.forEach { track in
                        track.isEnabled = true
                    }
                }
                
                player.play()
                
                // Set up observer for video end
                NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
                    .sink { _ in
                        isPresented = false
                    }
                    .store(in: &cancellables)
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
    }
}