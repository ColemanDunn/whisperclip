import SwiftUI
import AppKit

class RecordingOverlayManager {
    static let shared = RecordingOverlayManager()

    private var overlayWindow: NSPanel?

    private init() {
        // Subscribe to recording finish/error notifications to ensure overlay is hidden
        // even if ContentView is destroyed (e.g., main window closed during recording)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingFinished),
            name: .didFinishRecording,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingError),
            name: .recordingError,
            object: nil
        )
    }
    
    @objc private func handleRecordingFinished(_ notification: Notification) {
        hide()
    }
    
    @objc private func handleRecordingError(_ notification: Notification) {
        hide()
    }

    func show() {
        guard overlayWindow == nil else { return }

        // Use visibleFrame to avoid menu bar and Dock
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = NSSize(width: 320, height: 84)
        var origin = NSPoint(x: 0, y: 0)
        let padding: CGFloat = 20

        let position = SettingsStore.shared.overlayPosition
        switch position {
        case "topLeft":
            origin = NSPoint(x: visibleFrame.minX + padding, y: visibleFrame.maxY - windowSize.height - padding)
        case "topRight":
            origin = NSPoint(x: visibleFrame.maxX - windowSize.width - padding, y: visibleFrame.maxY - windowSize.height - padding)
        case "bottomLeft":
            origin = NSPoint(x: visibleFrame.minX + padding, y: visibleFrame.minY + padding)
        case "bottomRight":
            origin = NSPoint(x: visibleFrame.maxX - windowSize.width - padding, y: visibleFrame.minY + padding)
        default:
            origin = NSPoint(x: visibleFrame.maxX - windowSize.width - padding, y: visibleFrame.maxY - windowSize.height - padding)
        }

        let windowRect = NSRect(origin: origin, size: windowSize)

        let panel = NSPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let hostingView = NSHostingView(rootView: RecordingOverlayView().environmentObject(AudioRecorder.shared))
        hostingView.frame = NSRect(origin: .zero, size: windowSize)
        panel.contentView = hostingView

        panel.orderFrontRegardless()
        overlayWindow = panel
    }

    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}

struct RecordingOverlayView: View {
    @EnvironmentObject var audio: AudioRecorder

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.26),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.85),
                                    Color.white.opacity(0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                )

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 6, height: 6)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("LISTENING")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(Color.white.opacity(0.9))

                    OverlayWaveformView(audio: audio)
                        .frame(height: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 320, height: 84)
        .shadow(color: Color.black.opacity(0.22), radius: 20, x: 0, y: 8)
    }
}

private struct OverlayWaveformView: View {
    let audio: AudioRecorder

    @State private var levels: [CGFloat] = Array(repeating: 0.03, count: 72)
    @State private var sweepPosition: CGFloat = 0
    private let maxSamples = 72
    private let timer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let step = size.width / CGFloat(max(levels.count - 1, 1))

            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: midY))
            baseline.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(baseline, with: .color(Color.white.opacity(0.20)), lineWidth: 1)

            var upperWave = Path()
            var lowerWave = Path()
            upperWave.move(to: CGPoint(x: 0, y: midY))
            lowerWave.move(to: CGPoint(x: 0, y: midY))

            for (index, value) in levels.enumerated() {
                let x = CGFloat(index) * step
                let amplitude = max(1.5, min(size.height * 0.44, value * size.height * 0.95))
                upperWave.addLine(to: CGPoint(x: x, y: midY - amplitude))
                lowerWave.addLine(to: CGPoint(x: x, y: midY + amplitude))
            }

            let waveformGradient = Gradient(colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.98),
                Color.white.opacity(0.18)
            ])

            context.stroke(
                upperWave,
                with: .linearGradient(
                    waveformGradient,
                    startPoint: CGPoint(x: 0, y: midY),
                    endPoint: CGPoint(x: size.width, y: midY)
                ),
                lineWidth: 1.35
            )

            context.stroke(
                lowerWave,
                with: .linearGradient(
                    waveformGradient,
                    startPoint: CGPoint(x: 0, y: midY),
                    endPoint: CGPoint(x: size.width, y: midY)
                ),
                lineWidth: 1.35
            )

            let sweepX = sweepPosition * size.width
            let sweepRect = CGRect(x: sweepX - 20, y: 0, width: 40, height: size.height)
            context.fill(
                Path(sweepRect),
                with: .linearGradient(
                    Gradient(colors: [
                        .clear,
                        Color.white.opacity(0.20),
                        .clear
                    ]),
                    startPoint: CGPoint(x: sweepRect.minX, y: 0),
                    endPoint: CGPoint(x: sweepRect.maxX, y: 0)
                )
            )
        }
        .onReceive(timer) { _ in
            if audio.isRecording {
                let normalizedLevel = normalize(levelDB: audio.getLevel())
                let previous = levels.last ?? 0.03
                let smoothed = (previous * 0.68) + (normalizedLevel * 0.32)

                levels.append(smoothed)
                if levels.count > maxSamples {
                    levels.removeFirst(levels.count - maxSamples)
                }

                sweepPosition += 0.03
                if sweepPosition > 1 {
                    sweepPosition = 0
                }
            } else {
                levels = Array(repeating: 0.03, count: maxSamples)
                sweepPosition = 0
            }
        }
    }

    private func normalize(levelDB: Float) -> CGFloat {
        let clamped = min(max(levelDB, -58), -6)
        let normalized = (clamped + 58) / 52
        return CGFloat(max(0, min(1, normalized)))
    }
}
