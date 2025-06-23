import SwiftUI
import AVKit
import AVFoundation

// Reference-type model that lives once per screen
final class LoopingPlayerModel: ObservableObject {
    let player: AVQueuePlayer
    private let looper: AVPlayerLooper
    
    init(resource name: String, ext: String = "mp4", muted: Bool = true) {
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
        
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            fatalError("Video \(name).\(ext) not found in bundle")
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
        VideoPlayer(player: model.player)
            .disabled(true)
            .scaledToFill()
            .ignoresSafeArea()
            .onAppear { 
                model.player.play()
                print("Started playing video")
            }
            .onDisappear { 
                model.player.pause()
                print("Paused video")
            }
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    model.player.play()
                    print("Resumed video playback")
                case .background:
                    model.player.pause()
                    print("Paused video for background")
                default:
                    break
                }
            }
    }
}