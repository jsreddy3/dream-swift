import SwiftUI
import AVKit
import AVFoundation

// Reference-type model that lives once per screen
final class LoopingPlayerModel: ObservableObject {
    let player: AVQueuePlayer?  // ← Made optional
    private let looper: AVPlayerLooper?  // ← Made optional
    
    init(resource name: String, ext: String = "mp4", muted: Bool = true) {
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
        
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Video \(name).\(ext) not found - preview mode?")  // ← Changed from fatalError
            self.player = nil  // ← Set nil instead of crashing
            self.looper = nil
            return
        }
        
        print("Found video at: \(url)")
        
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = muted
        queuePlayer.automaticallyWaitsToMinimizeStalling = false
        
        self.looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        self.player = queuePlayer
    }
}

// Thin SwiftUI wrapper
struct LoopingVideoView: View {
    @StateObject private var model: LoopingPlayerModel
    @Environment(\.scenePhase) private var scenePhase
    
    init(named name: String, fileExtension ext: String = "mp4", muted: Bool = true) {
        _model = StateObject(wrappedValue: LoopingPlayerModel(resource: name, ext: ext, muted: muted))
    }
    
    var body: some View {
        Group {  // ← Added Group
            if let player = model.player {  // ← Added nil check
                VideoPlayer(player: player)
                    .disabled(true)
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .onAppear {
                        player.play()  // ← Now using unwrapped player
                        print("Started playing video")
                    }
                    .onDisappear {
                        player.pause()  // ← Now using unwrapped player
                        print("Paused video")
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        switch newPhase {
                        case .active:
                            player.play()  // ← Now using unwrapped player
                            print("Resumed video playback")
                        case .background:
                            player.pause()  // ← Now using unwrapped player
                            print("Paused video for background")
                        default:
                            break
                        }
                    }
            } else {
                Color.black  // ← Invisible placeholder for preview
            }
        }
    }
}
