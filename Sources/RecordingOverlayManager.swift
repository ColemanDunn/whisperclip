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

        let tuning = OverlayWaveformTuning.shared

        // Use visibleFrame to avoid menu bar and Dock
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = NSSize(width: tuning.windowWidth, height: tuning.windowHeight)
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
        panel.ignoresMouseEvents = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let hostingView = NSHostingView(rootView: RecordingOverlayView().environmentObject(AudioRecorder.shared))
        hostingView.frame = NSRect(origin: .zero, size: windowSize)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
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
    @ObservedObject private var tuning = OverlayWaveformTuning.shared

    var body: some View {
        let isDev = tuning.isDevMode

        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.09, blue: 0.10).opacity(0.93),
                            Color.black.opacity(0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.8)
                        .padding(1)
                )

            VStack(spacing: isDev ? 8 : 10) {
                OverlayWaveformView(audio: audio)
                    .frame(height: 56)
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                HStack(spacing: 12) {
                    Circle()
                        .fill(audio.isRecording ? Color.white.opacity(0.82) : Color.white.opacity(0.34))
                        .frame(width: 8, height: 8)
                    Text(audio.isRecording ? "Listening" : "Idle")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.65))

                    Spacer(minLength: 12)

                    OverlayActionButton(title: "Stop", systemImage: "stop.fill") {
                        audio.stop()
                    }
                    .disabled(!audio.isRecording)

                    OverlayActionButton(title: "Cancel", systemImage: "xmark") {
                        audio.reset()
                        RecordingOverlayManager.shared.hide()
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.46))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, isDev ? 0 : 10)

                if isDev {
                    OverlayWaveformDevPanel(tuning: tuning)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(width: tuning.windowWidth, height: tuning.windowHeight)
        .background(Color.clear)
    }
}

private struct OverlayActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(isEnabled ? 0.88 : 0.38))
                .padding(.horizontal, 11)
                .frame(height: 30)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(isEnabled ? 0.14 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(isEnabled ? 0.11 : 0.05), lineWidth: 0.6)
        )
    }
}

private final class OverlayWaveformTuning: ObservableObject {
    static let shared = OverlayWaveformTuning()

    let isDevMode: Bool

    // Rendering
    @Published var barCount: Double = 168
    @Published var barSpacing: Double = 1.15
    @Published var amplitudeExponent: Double = 0.70
    @Published var amplitudeScale: Double = 1.12

    // Mic normalization / gating
    @Published var speechPeakDB: Double = -7.5
    @Published var gateStart: Double = 0.32
    @Published var gateCurve: Double = 0.62
    @Published var noiseAdaptThresholdDB: Double = 5.0
    @Published var noiseAdaptRate: Double = 0.0012
    @Published var noiseFloorMinDB: Double = -70
    @Published var noiseFloorMaxDB: Double = -49

    // Envelope tracking
    @Published var globalAttack: Double = 1.0
    @Published var globalRelease: Double = 0.94
    @Published var transientDecay: Double = 0.20
    @Published var transientGain: Double = 0.90

    // Shape / texture
    @Published var minShape: Double = 0.37
    @Published var centerCurve: Double = 0.79
    @Published var textureAmount: Double = 0.29
    @Published var activeGain: Double = 0.46
    @Published var spikeGain: Double = 0.60

    // Clustered stochastic behavior (group-level, not full-width)
    @Published var impulseDensity: Double = 3.9
    @Published var impulseBase: Double = 0.045
    @Published var impulseStrength: Double = 0.24
    @Published var groupCarry: Double = 0.66
    @Published var groupNeighbor: Double = 0.17
    @Published var groupDecayActive: Double = 0.90
    @Published var groupDecayIdle: Double = 0.39
    @Published var modulationBase: Double = 0.01
    @Published var modulationScale: Double = 0.71
    @Published var liftBase: Double = 0.012
    @Published var liftScale: Double = 0.03

    // Spatial wave grouping controls
    @Published var waveLengthBars: Double = 12.0
    @Published var waveDepth: Double = 0.90
    @Published var waveShiftSpeed: Double = 0.09
    @Published var waveJitter: Double = 0.20

    // Bar response / idle floor
    @Published var barAttack: Double = 0.96
    @Published var barRelease: Double = 0.95
    @Published var idleGateEnergy: Double = 0.019
    @Published var idleFloorBase: Double = 0.010
    @Published var idleFloorShape: Double = 0.0014
    @Published var barFloor: Double = 0.0012

    var windowWidth: CGFloat { isDevMode ? 620 : 500 }
    var windowHeight: CGFloat { isDevMode ? 560 : 136 }

    private init() {
        isDevMode =
            CommandLine.arguments.contains("--overlay-dev") ||
            ProcessInfo.processInfo.environment["WHISPERCLIP_OVERLAY_DEV"] == "1"
    }

    func resetToDefaults() {
        barCount = 168
        barSpacing = 1.15
        amplitudeExponent = 0.70
        amplitudeScale = 1.12

        speechPeakDB = -7.5
        gateStart = 0.32
        gateCurve = 0.62
        noiseAdaptThresholdDB = 5.0
        noiseAdaptRate = 0.0012
        noiseFloorMinDB = -70
        noiseFloorMaxDB = -49

        globalAttack = 1.0
        globalRelease = 0.94
        transientDecay = 0.20
        transientGain = 0.90

        minShape = 0.37
        centerCurve = 0.79
        textureAmount = 0.29
        activeGain = 0.46
        spikeGain = 0.60

        impulseDensity = 3.9
        impulseBase = 0.045
        impulseStrength = 0.24
        groupCarry = 0.66
        groupNeighbor = 0.17
        groupDecayActive = 0.90
        groupDecayIdle = 0.39
        modulationBase = 0.01
        modulationScale = 0.71
        liftBase = 0.012
        liftScale = 0.03

        waveLengthBars = 12.0
        waveDepth = 0.90
        waveShiftSpeed = 0.09
        waveJitter = 0.20

        barAttack = 0.96
        barRelease = 0.95
        idleGateEnergy = 0.019
        idleFloorBase = 0.010
        idleFloorShape = 0.0014
        barFloor = 0.0012
    }

    func exportValuesText() -> String {
        let lines = [
            "barCount=\(Int(barCount.rounded()))",
            "barSpacing=\(fmt(barSpacing))",
            "amplitudeExponent=\(fmt(amplitudeExponent))",
            "amplitudeScale=\(fmt(amplitudeScale))",
            "speechPeakDB=\(fmt(speechPeakDB))",
            "gateStart=\(fmt(gateStart))",
            "gateCurve=\(fmt(gateCurve))",
            "noiseAdaptThresholdDB=\(fmt(noiseAdaptThresholdDB))",
            "noiseAdaptRate=\(fmt(noiseAdaptRate))",
            "noiseFloorMinDB=\(fmt(noiseFloorMinDB))",
            "noiseFloorMaxDB=\(fmt(noiseFloorMaxDB))",
            "globalAttack=\(fmt(globalAttack))",
            "globalRelease=\(fmt(globalRelease))",
            "transientDecay=\(fmt(transientDecay))",
            "transientGain=\(fmt(transientGain))",
            "minShape=\(fmt(minShape))",
            "centerCurve=\(fmt(centerCurve))",
            "textureAmount=\(fmt(textureAmount))",
            "activeGain=\(fmt(activeGain))",
            "spikeGain=\(fmt(spikeGain))",
            "impulseDensity=\(fmt(impulseDensity))",
            "impulseBase=\(fmt(impulseBase))",
            "impulseStrength=\(fmt(impulseStrength))",
            "groupCarry=\(fmt(groupCarry))",
            "groupNeighbor=\(fmt(groupNeighbor))",
            "groupDecayActive=\(fmt(groupDecayActive))",
            "groupDecayIdle=\(fmt(groupDecayIdle))",
            "modulationBase=\(fmt(modulationBase))",
            "modulationScale=\(fmt(modulationScale))",
            "liftBase=\(fmt(liftBase))",
            "liftScale=\(fmt(liftScale))",
            "waveLengthBars=\(fmt(waveLengthBars))",
            "waveDepth=\(fmt(waveDepth))",
            "waveShiftSpeed=\(fmt(waveShiftSpeed))",
            "waveJitter=\(fmt(waveJitter))",
            "barAttack=\(fmt(barAttack))",
            "barRelease=\(fmt(barRelease))",
            "idleGateEnergy=\(fmt(idleGateEnergy))",
            "idleFloorBase=\(fmt(idleFloorBase))",
            "idleFloorShape=\(fmt(idleFloorShape))",
            "barFloor=\(fmt(barFloor))"
        ]
        return lines.joined(separator: "\n")
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

private struct OverlayWaveformView: View {
    let audio: AudioRecorder

    @ObservedObject private var tuning = OverlayWaveformTuning.shared

    @State private var bars: [CGFloat] = Array(repeating: 0, count: 104)
    @State private var stochasticState: [CGFloat] = Array(repeating: 0, count: 104)
    @State private var displayEnergy: CGFloat = 0
    @State private var transientEnergy: CGFloat = 0
    @State private var adaptiveNoiseFloor: CGFloat = -56
    @State private var waveClock: CGFloat = 0
    private let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { context, size in
            guard !bars.isEmpty else { return }

            var baseline = Path()
            let midY = size.height / 2
            baseline.move(to: CGPoint(x: 0, y: midY))
            baseline.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(baseline, with: .color(Color.white.opacity(0.11)), lineWidth: 1)

            let spacing = CGFloat(tuning.barSpacing)
            let totalSpacing = spacing * CGFloat(max(0, bars.count - 1))
            let barWidth = max(1.0, (size.width - totalSpacing) / CGFloat(max(1, bars.count)))

            for (index, value) in bars.enumerated() {
                if value < 0.0012 { continue }
                let x = CGFloat(index) * (barWidth + spacing)
                let amplitude = pow(value, CGFloat(tuning.amplitudeExponent)) * (size.height * CGFloat(tuning.amplitudeScale))
                let barHeight = max(1.0, amplitude * 2)
                let y = midY - (barHeight / 2)

                let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                let brightness = 0.72 + (value * 0.24)
                let opacity = 0.10 + (value * 0.9)

                context.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(Color(white: brightness, opacity: opacity))
                )
            }
        }
        .onReceive(timer) { _ in
            updateWaveform()
        }
    }

    private func updateWaveform() {
        ensureCapacity()
        guard !bars.isEmpty else { return }

        waveClock += CGFloat(tuning.waveShiftSpeed)

        let dbLevel = audio.isRecording ? audio.getLevel() : -160
        let instantEnergy = normalize(levelDB: dbLevel, noiseFloor: adaptiveNoiseFloor)

        let dbAsCGFloat = CGFloat(dbLevel)
        if dbAsCGFloat < adaptiveNoiseFloor + CGFloat(tuning.noiseAdaptThresholdDB) {
            let rate = CGFloat(tuning.noiseAdaptRate)
            adaptiveNoiseFloor = (adaptiveNoiseFloor * (1 - rate)) + (dbAsCGFloat * rate)
        }
        adaptiveNoiseFloor = min(max(adaptiveNoiseFloor, CGFloat(tuning.noiseFloorMinDB)), CGFloat(tuning.noiseFloorMaxDB))

        let globalAttack = CGFloat(tuning.globalAttack)
        let globalRelease = CGFloat(tuning.globalRelease)
        let globalResponse = instantEnergy > displayEnergy ? globalAttack : globalRelease
        displayEnergy += (instantEnergy - displayEnergy) * globalResponse

        let transient = max(0, instantEnergy - displayEnergy)
        transientEnergy = max(transientEnergy * CGFloat(tuning.transientDecay), transient * CGFloat(tuning.transientGain))
        let energyMix = min(1, (displayEnergy * 1.15) + (transientEnergy * 0.90))
        let liveActivity = min(1, instantEnergy / max(0.0001, CGFloat(tuning.idleGateEnergy) * 2.2))

        // Inject grouped impulses in 5-bar neighborhoods.
        if liveActivity > 0.02, bars.count > 5 {
            let kernel: [CGFloat] = [0.30, 0.62, 1.0, 0.62, 0.30]
            let impulseCount = max(1, Int((energyMix * liveActivity * CGFloat(tuning.impulseDensity)).rounded(.down)))

            for _ in 0..<impulseCount {
                let center = Int.random(in: 2..<(bars.count - 2))
                let dynamicLength = max(
                    2,
                    CGFloat(tuning.waveLengthBars) * (1 + (sin(waveClock * 0.37) * CGFloat(tuning.waveJitter)))
                )
                let phase = (CGFloat(center) / dynamicLength) * (.pi * 2) + waveClock
                let localWave = sin(phase)
                let impulseBias = 0.55 + (0.45 * abs(localWave))
                let impulseRange = (CGFloat(tuning.impulseBase) + (energyMix * CGFloat(tuning.impulseStrength))) * impulseBias
                let impulse = CGFloat.random(in: -1...1) * impulseRange

                for offset in -2...2 {
                    stochasticState[center + offset] += impulse * kernel[offset + 2]
                }
            }
        }

        let countMinusOne = CGFloat(max(1, bars.count - 1))
        let snapshot = stochasticState
        var nextBars = bars
        let responsiveEnergy = min(displayEnergy, (displayEnergy * 0.30) + (instantEnergy * 0.70))
        let dynamicWaveLength = max(
            2,
            CGFloat(tuning.waveLengthBars) * (1 + (sin(waveClock * 0.29) * CGFloat(tuning.waveJitter)))
        )

        for index in bars.indices {
            let x = CGFloat(index) / countMinusOne
            let centerFalloff = pow(max(0, 1 - abs(x - 0.5) * 2), CGFloat(tuning.centerCurve))
            let shape = CGFloat(tuning.minShape) + ((1 - CGFloat(tuning.minShape)) * centerFalloff)
            let staticTexture = (1 - CGFloat(tuning.textureAmount)) + (CGFloat(tuning.textureAmount) * sin((CGFloat(index) * 1.11) + 0.9))

            let active = responsiveEnergy * shape * staticTexture
            let spike = transientEnergy * (0.45 + (0.55 * shape))

            let state = snapshot[index]
            let left = index > 0 ? snapshot[index - 1] : state
            let right = index + 1 < snapshot.count ? snapshot[index + 1] : state
            var groupState = (state * CGFloat(tuning.groupCarry)) + (((left + right) * 0.5) * CGFloat(tuning.groupNeighbor))

            let phase = (CGFloat(index) / dynamicWaveLength) * (.pi * 2) + waveClock
            let clusterWave = (sin(phase) + (0.35 * sin((phase * 2.1) + (waveClock * 0.7)))) / 1.35
            groupState += clusterWave * CGFloat(tuning.waveDepth) * liveActivity
            groupState *= energyMix > CGFloat(tuning.idleGateEnergy) ? CGFloat(tuning.groupDecayActive) : CGFloat(tuning.groupDecayIdle)
            groupState = min(max(groupState, -1.8), 1.8)
            stochasticState[index] = groupState

            let modulation = groupState * liveActivity * (CGFloat(tuning.modulationBase) + (energyMix * CGFloat(tuning.modulationScale)))
            var target = (active * CGFloat(tuning.activeGain)) + (spike * CGFloat(tuning.spikeGain))
            target *= max(0.05, 1 + modulation)
            target += abs(groupState) * liveActivity * (CGFloat(tuning.liftBase) + (energyMix * CGFloat(tuning.liftScale)))
            target = min(max(target, 0), 1)

            if liveActivity < 0.06 {
                let idleNotch = CGFloat(tuning.idleFloorBase) + (CGFloat(tuning.idleFloorShape) * shape)
                target = idleNotch
                stochasticState[index] *= 0.22
            }

            let current = bars[index]
            let response = target > current ? CGFloat(tuning.barAttack) : CGFloat(tuning.barRelease)
            var updated = current + ((target - current) * response)
            updated += groupState * (0.0006 + (energyMix * 0.002))

            if liveActivity < 0.06 {
                updated = max(updated * 0.58, CGFloat(tuning.barFloor))
            }
            if updated < CGFloat(tuning.barFloor) {
                updated = CGFloat(tuning.barFloor)
            }
            nextBars[index] = updated
        }

        bars = nextBars
    }

    private func ensureCapacity() {
        let desiredCount = Int(max(24, min(220, tuning.barCount.rounded())))
        guard desiredCount != bars.count else { return }

        if desiredCount > bars.count {
            bars.append(contentsOf: Array(repeating: CGFloat(tuning.barFloor), count: desiredCount - bars.count))
            stochasticState.append(contentsOf: Array(repeating: 0, count: desiredCount - stochasticState.count))
        } else {
            bars = Array(bars.prefix(desiredCount))
            stochasticState = Array(stochasticState.prefix(desiredCount))
        }
    }

    private func normalize(levelDB: Float, noiseFloor: CGFloat) -> CGFloat {
        let floor = noiseFloor
        let speechPeak = CGFloat(tuning.speechPeakDB)
        let clamped = min(max(CGFloat(levelDB), floor), speechPeak)
        let normalized = (clamped - floor) / max(0.001, speechPeak - floor)
        let gateStart = CGFloat(tuning.gateStart)
        let gated = max(0, (normalized - gateStart) / max(0.001, 1 - gateStart))
        return pow(gated, CGFloat(tuning.gateCurve))
    }
}

private struct OverlayWaveformDevPanel: View {
    @ObservedObject var tuning: OverlayWaveformTuning
    @State private var copiedValues: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Overlay Dev Tuning")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.86))
                Spacer()
                Button("Reset") {
                    tuning.resetToDefaults()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.78))
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.10)))

                Button("Copy Values") {
                    let text = tuning.exportValuesText()
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    copiedValues = text
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.90))
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.18)))
            }

            ScrollView {
                VStack(spacing: 8) {
                    OverlayDevSlider(title: "Bars", value: $tuning.barCount, range: 48...180, step: 1, format: "%.0f")
                    OverlayDevSlider(title: "Bar Spacing", value: $tuning.barSpacing, range: 0.8...3.0, step: 0.05, format: "%.2f")
                    OverlayDevSlider(title: "Amp Exponent", value: $tuning.amplitudeExponent, range: 0.45...1.15, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Amp Scale", value: $tuning.amplitudeScale, range: 0.65...1.8, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Speech Peak dB", value: $tuning.speechPeakDB, range: -20...0, step: 0.5, format: "%.1f")
                    OverlayDevSlider(title: "Gate Start", value: $tuning.gateStart, range: 0.05...0.8, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Gate Curve", value: $tuning.gateCurve, range: 0.25...1.4, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Global Attack", value: $tuning.globalAttack, range: 0.30...1.0, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Global Release", value: $tuning.globalRelease, range: 0.05...0.95, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Transient Decay", value: $tuning.transientDecay, range: 0.20...0.95, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Transient Gain", value: $tuning.transientGain, range: 0.30...2.2, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Center Min Shape", value: $tuning.minShape, range: 0.25...0.95, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Center Curve", value: $tuning.centerCurve, range: 0.30...1.4, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Texture Amount", value: $tuning.textureAmount, range: 0.0...0.45, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Active Gain", value: $tuning.activeGain, range: 0.2...1.8, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Spike Gain", value: $tuning.spikeGain, range: 0.1...2.0, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Impulse Density", value: $tuning.impulseDensity, range: 0.5...10.0, step: 0.1, format: "%.1f")
                    OverlayDevSlider(title: "Impulse Base", value: $tuning.impulseBase, range: 0.0...0.2, step: 0.005, format: "%.3f")
                    OverlayDevSlider(title: "Impulse Strength", value: $tuning.impulseStrength, range: 0.0...0.8, step: 0.005, format: "%.3f")
                    OverlayDevSlider(title: "Group Carry", value: $tuning.groupCarry, range: 0.1...0.95, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Group Neighbor", value: $tuning.groupNeighbor, range: 0.0...0.45, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Group Decay Active", value: $tuning.groupDecayActive, range: 0.40...0.99, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Group Decay Idle", value: $tuning.groupDecayIdle, range: 0.05...0.80, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Modulation Base", value: $tuning.modulationBase, range: 0.0...0.30, step: 0.005, format: "%.3f")
                    OverlayDevSlider(title: "Modulation Scale", value: $tuning.modulationScale, range: 0.0...1.4, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Wave Length (bars)", value: $tuning.waveLengthBars, range: 3...40, step: 0.5, format: "%.1f")
                    OverlayDevSlider(title: "Wave Depth", value: $tuning.waveDepth, range: 0.0...1.2, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Wave Shift Speed", value: $tuning.waveShiftSpeed, range: 0.0...0.45, step: 0.005, format: "%.3f")
                    OverlayDevSlider(title: "Wave Length Jitter", value: $tuning.waveJitter, range: 0.0...0.7, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Bar Attack", value: $tuning.barAttack, range: 0.40...1.0, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Bar Release", value: $tuning.barRelease, range: 0.08...0.95, step: 0.01, format: "%.2f")
                    OverlayDevSlider(title: "Idle Gate Energy", value: $tuning.idleGateEnergy, range: 0.001...0.06, step: 0.001, format: "%.3f")
                    OverlayDevSlider(title: "Idle Floor Base", value: $tuning.idleFloorBase, range: 0.0004...0.01, step: 0.0002, format: "%.4f")
                    OverlayDevSlider(title: "Idle Floor Shape", value: $tuning.idleFloorShape, range: 0.0004...0.02, step: 0.0002, format: "%.4f")
                }
            }
            .frame(maxHeight: 250)

            if !copiedValues.isEmpty {
                Text(copiedValues)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.25))
                    )
            }

            Text("Tip: launch with ./local_dev_overlay.sh for fast overlay tuning.")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.50))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
        )
    }
}

private struct OverlayDevSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.76))
                    Text(descriptionText)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: format, value))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.92))
                    Text(humanValueText)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
            }
            Slider(value: $value, in: range, step: step)
                .tint(Color.white.opacity(0.85))
        }
    }

    private var descriptionText: String {
        switch title {
        case "Bars":
            return "How many bar columns are shown across the waveform."
        case "Bar Spacing":
            return "Gap between neighboring bars."
        case "Amp Exponent":
            return "How strongly low vs high energy is expanded visually."
        case "Amp Scale":
            return "Overall waveform height multiplier."
        case "Speech Peak dB":
            return "Mic level treated as the top of the normalized range."
        case "Gate Start":
            return "Noise gate start point before signal becomes visible."
        case "Gate Curve":
            return "Curve applied after gate; higher requires stronger input."
        case "Global Attack":
            return "How quickly overall energy rises."
        case "Global Release":
            return "How quickly overall energy falls."
        case "Transient Decay":
            return "How long short spikes persist."
        case "Transient Gain":
            return "How much transients boost fast spikes."
        case "Center Min Shape":
            return "Minimum side energy vs center emphasis."
        case "Center Curve":
            return "How strongly center weighting is shaped."
        case "Texture Amount":
            return "Static per-bar variation to prevent a flat block."
        case "Active Gain":
            return "Gain for continuous voice energy."
        case "Spike Gain":
            return "Gain for sudden voice changes."
        case "Impulse Density":
            return "How many grouped stochastic pulses happen each frame."
        case "Impulse Base":
            return "Base size of random grouped pulses."
        case "Impulse Strength":
            return "Extra random pulse size at higher energy."
        case "Group Carry":
            return "How much each bar keeps its prior group state."
        case "Group Neighbor":
            return "How much nearby bars influence each other."
        case "Group Decay Active":
            return "How fast grouped motion decays while speaking."
        case "Group Decay Idle":
            return "How fast grouped motion decays in silence."
        case "Modulation Base":
            return "Base amount grouped motion modulates amplitude."
        case "Modulation Scale":
            return "Extra modulation depth when energy is high."
        case "Wave Length (bars)":
            return "Size of stochastic wave groups measured in bars."
        case "Wave Depth":
            return "How deep grouped waves dip/rise inside the waveform."
        case "Wave Shift Speed":
            return "How fast the grouped-wave pattern evolves over time."
        case "Wave Length Jitter":
            return "How much wave-group size drifts over time."
        case "Bar Attack":
            return "How quickly each individual bar rises."
        case "Bar Release":
            return "How quickly each individual bar drops."
        case "Idle Gate Energy":
            return "Threshold below which waveform stays in tiny idle mode."
        case "Idle Floor Base":
            return "Minimum idle notch size."
        case "Idle Floor Shape":
            return "Extra idle notch size from center-shape weighting."
        default:
            return "Adjusts waveform behavior."
        }
    }

    private var humanValueText: String {
        switch title {
        case "Bars":
            return "\(Int(value.rounded())) bars"
        case "Bar Spacing":
            if value < 1.2 { return "tight spacing" }
            if value < 2.1 { return "balanced spacing" }
            return "wide spacing"
        case "Amp Exponent":
            if value < 0.60 { return "boosts quieter motion" }
            if value < 0.86 { return "balanced amplitude curve" }
            return "emphasizes loud peaks"
        case "Amp Scale":
            if value < 0.9 { return "short waveform" }
            if value < 1.25 { return "balanced height" }
            return "tall waveform"
        case "Speech Peak dB":
            if value > -5 { return "hot / saturates early" }
            if value > -10 { return "balanced headroom" }
            return "more headroom"
        case "Gate Start":
            if value < 0.22 { return "very sensitive gate" }
            if value < 0.45 { return "balanced gate" }
            return "aggressive noise gate"
        case "Gate Curve":
            if value < 0.55 { return "quiet sounds emphasized" }
            if value < 0.95 { return "balanced curve" }
            return "needs stronger input"
        case "Global Attack":
            if value < 0.60 { return "slow rise" }
            if value < 0.86 { return "medium rise" }
            return "very fast rise"
        case "Global Release":
            if value < 0.20 { return "long decay" }
            if value < 0.50 { return "balanced decay" }
            return "snappy decay"
        case "Transient Decay":
            if value < 0.35 { return "sharp transients" }
            if value < 0.65 { return "balanced transients" }
            return "lingering transients"
        case "Transient Gain":
            if value < 0.8 { return "subtle spikes" }
            if value < 1.5 { return "balanced spikes" }
            return "strong spikes"
        case "Center Min Shape":
            if value < 0.45 { return "strong center focus" }
            if value < 0.75 { return "balanced spread" }
            return "flatter across width"
        case "Center Curve":
            if value < 0.55 { return "flat center shape" }
            if value < 0.95 { return "balanced center shape" }
            return "pronounced center shape"
        case "Texture Amount":
            if value < 0.08 { return "smooth bars" }
            if value < 0.22 { return "balanced texture" }
            return "high texture"
        case "Active Gain":
            if value < 0.7 { return "quieter sustained response" }
            if value < 1.2 { return "balanced sustained response" }
            return "loud sustained response"
        case "Spike Gain":
            if value < 0.45 { return "gentle spike response" }
            if value < 0.95 { return "balanced spike response" }
            return "aggressive spike response"
        case "Impulse Density":
            if value < 2.0 { return "few grouped pulses" }
            if value < 6.0 { return "balanced grouped pulses" }
            return "many grouped pulses"
        case "Impulse Base":
            if value < 0.03 { return "soft pulse floor" }
            if value < 0.09 { return "balanced pulse floor" }
            return "strong pulse floor"
        case "Impulse Strength":
            if value < 0.12 { return "light dynamic pulses" }
            if value < 0.30 { return "balanced dynamic pulses" }
            return "strong dynamic pulses"
        case "Group Carry":
            if value < 0.40 { return "choppy groups" }
            if value < 0.72 { return "balanced continuity" }
            return "smooth group continuity"
        case "Group Neighbor":
            if value < 0.10 { return "independent bars" }
            if value < 0.24 { return "balanced local coupling" }
            return "tightly coupled groups"
        case "Group Decay Active":
            if value < 0.70 { return "fast active decay" }
            if value < 0.90 { return "balanced active decay" }
            return "slow active decay"
        case "Group Decay Idle":
            if value < 0.25 { return "idle clears quickly" }
            if value < 0.50 { return "balanced idle decay" }
            return "idle lingers"
        case "Modulation Base":
            if value < 0.05 { return "subtle modulation" }
            if value < 0.14 { return "balanced modulation" }
            return "strong modulation"
        case "Modulation Scale":
            if value < 0.35 { return "low energy scaling" }
            if value < 0.85 { return "balanced scaling" }
            return "high energy scaling"
        case "Wave Length (bars)":
            if value < 7 { return "small bar groups" }
            if value < 18 { return "medium bar groups" }
            return "large bar groups"
        case "Wave Depth":
            if value < 0.3 { return "shallow grouped waves" }
            if value < 0.75 { return "balanced grouped waves" }
            return "deep grouped waves"
        case "Wave Shift Speed":
            if value < 0.05 { return "slow group drift" }
            if value < 0.16 { return "balanced group drift" }
            return "fast group drift"
        case "Wave Length Jitter":
            if value < 0.15 { return "stable group size" }
            if value < 0.35 { return "balanced group variation" }
            return "wild group variation"
        case "Bar Attack":
            if value < 0.70 { return "slow bar rise" }
            if value < 0.90 { return "balanced bar rise" }
            return "instant bar rise"
        case "Bar Release":
            if value < 0.30 { return "long bar tails" }
            if value < 0.70 { return "balanced bar tails" }
            return "very snappy drop"
        case "Idle Gate Energy":
            if value < 0.006 { return "stays active in quiet" }
            if value < 0.015 { return "balanced idle switch" }
            return "idle engages early"
        case "Idle Floor Base":
            if value < 0.0012 { return "tiny idle notches" }
            if value < 0.0030 { return "balanced idle notches" }
            return "visible idle notches"
        case "Idle Floor Shape":
            if value < 0.0012 { return "flat idle profile" }
            if value < 0.0030 { return "balanced idle profile" }
            return "center-weighted idle profile"
        default:
            return qualitativeLevel(value, in: range)
        }
    }

    private func qualitativeLevel(_ value: Double, in range: ClosedRange<Double>) -> String {
        let span = max(0.0001, range.upperBound - range.lowerBound)
        let normalized = (value - range.lowerBound) / span
        if normalized < 0.20 { return "very low" }
        if normalized < 0.40 { return "low" }
        if normalized < 0.65 { return "medium" }
        if normalized < 0.85 { return "high" }
        return "very high"
    }
}
