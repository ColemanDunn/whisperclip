import Foundation
import AVFoundation

final class RecordingSoundManager {
    static let shared = RecordingSoundManager()

    private let startPlayer: AVAudioPlayer?
    private let stopPlayer: AVAudioPlayer?

    private init() {
        startPlayer = RecordingSoundManager.makePlayer(for: "Funk")
        stopPlayer = RecordingSoundManager.makePlayer(for: "Glass")
    }

    private static func makePlayer(for soundName: String) -> AVAudioPlayer? {
        let soundURL = URL(fileURLWithPath: "/System/Library/Sounds/\(soundName).aiff")
        guard FileManager.default.fileExists(atPath: soundURL.path),
              let player = try? AVAudioPlayer(contentsOf: soundURL) else {
            return nil
        }
        player.prepareToPlay()
        player.volume = 0.85
        return player
    }

    private func play(_ player: AVAudioPlayer?) {
        guard SettingsStore.shared.recordingSoundsEnabled else { return }
        guard let player else { return }
        DispatchQueue.main.async {
            if player.isPlaying {
                player.stop()
                player.currentTime = 0
            }
            player.play()
        }
    }

    func playStart() {
        play(startPlayer)
    }

    func playStop() {
        play(stopPlayer)
    }
}
