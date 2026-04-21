@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
@preconcurrency import Speech

@MainActor
final class VoiceCommandController: NSObject, ObservableObject {
    enum VoiceCommandError: LocalizedError {
        case microphonePermissionDenied
        case speechPermissionDenied
        case recognizerUnavailable
        case recognizerLocaleUnsupported
        case invalidAudioInputFormat(sampleRate: Double, channelCount: AVAudioChannelCount)

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "Microphone access is required for voice tool switching."
            case .speechPermissionDenied:
                return "Speech recognition access is required for voice tool switching."
            case .recognizerUnavailable:
                return "Speech recognition is currently unavailable."
            case .recognizerLocaleUnsupported:
                return "This device couldn't create an English speech recognizer."
            case let .invalidAudioInputFormat(sampleRate, channelCount):
                return "Audio input is unavailable or invalid. Sample rate: \(sampleRate), channels: \(channelCount). If this is Simulator, check its audio input or try a real iPad."
            }
        }
    }

    @Published var isListening = false
    @Published var audioLevel: CGFloat = 0
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 5)
    @Published var isStatusVisible = false
    @Published var transcript = ""
    @Published var statusMessage = ""

    var onCommand: ((InkCommand) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private var statusDismissalTask: Task<Void, Never>?
    private var activeRecognitionSessionID: UUID?
    private var pendingCommand: InkCommand?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))

    func toggleListening(trigger: String) async {
        if isListening {
            stopListening(status: "Stopped listening.")
        } else {
            await startListening(trigger: trigger)
        }
    }

    func startListening(trigger: String) async {
        do {
            try await requestPermissionsIfNeeded()
            try beginRecognitionSession(trigger: trigger)
        } catch {
            showStatus(error.localizedDescription, autoHide: true)
        }
    }

    func stopListening(status: String? = nil) {
        timeoutTask?.cancel()
        timeoutTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        activeRecognitionSessionID = nil
        pendingCommand = nil
        isListening = false
        audioLevel = 0
        audioLevels = Array(repeating: 0, count: audioLevels.count)

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if let status {
            showStatus(status, autoHide: true)
        }
    }

    func clearStatus() {
        stopListening()
        statusDismissalTask?.cancel()
        statusDismissalTask = nil
        transcript = ""
        statusMessage = ""
        isStatusVisible = false
        audioLevel = 0
        audioLevels = Array(repeating: 0, count: audioLevels.count)
    }

    func showSimulatorFallbackStatus(_ message: String) {
        showStatus(message, autoHide: true)
    }

    private func requestPermissionsIfNeeded() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw VoiceCommandError.speechPermissionDenied
        }

        let microphoneAuthorized = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { @Sendable granted in
                continuation.resume(returning: granted)
            }
        }

        guard microphoneAuthorized else {
            throw VoiceCommandError.microphonePermissionDenied
        }
    }

    private func beginRecognitionSession(trigger: String) throws {
        guard let speechRecognizer else {
            throw VoiceCommandError.recognizerLocaleUnsupported
        }

        guard speechRecognizer.isAvailable else {
            throw VoiceCommandError.recognizerUnavailable
        }

        stopListening()

        let sessionID = UUID()
        activeRecognitionSessionID = sessionID
        transcript = ""
        showStatus("Listening after \(trigger).", autoHide: false)

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        recognitionRequest = request
        let requestAppender = SpeechAudioBufferAppender(request: request)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw VoiceCommandError.invalidAudioInputFormat(
                sampleRate: recordingFormat.sampleRate,
                channelCount: recordingFormat.channelCount
            )
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { @Sendable [weak self] buffer, _ in
            requestAppender.append(buffer)
            let levels = buffer.normalizedAudioLevels(barCount: 5)
            let peakLevel = levels.max() ?? 0

            Task { @MainActor [weak self] in
                guard
                    let self,
                    self.activeRecognitionSessionID == sessionID,
                    self.isListening
                else {
                    return
                }

                self.audioLevels = self.smoothedAudioLevels(from: levels)

                let response: CGFloat = peakLevel > self.audioLevel ? 0.62 : 0.22
                self.audioLevel += (peakLevel - self.audioLevel) * response
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
            let spokenText = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let errorDescription = error?.localizedDescription
            let command = spokenText.flatMap(InkCommand.parse)

            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.activeRecognitionSessionID == sessionID else { return }

                if let command {
                    self.pendingCommand = command
                }

                if let spokenText {
                    self.transcript = spokenText
                }

                if let pendingCommand = self.pendingCommand {
                    self.onCommand?(pendingCommand)
                    self.stopListening(status: "Applied \(pendingCommand.displayName).")
                    return
                }

                if let spokenText, isFinal {
                    self.stopListening(
                        status: "Heard \"\(spokenText)\", but it didn't match a supported tool command."
                    )
                    return
                }

                if let errorDescription {
                    guard !errorDescription.localizedCaseInsensitiveContains("No speech detected") else {
                        return
                    }

                    if let transcriptCommand = InkCommand.parse(self.transcript) {
                        self.onCommand?(transcriptCommand)
                        self.stopListening(status: "Applied \(transcriptCommand.displayName).")
                    } else {
                        self.stopListening(status: "Voice control failed: \(errorDescription)")
                    }
                }
            }
        }

        timeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard self.isListening else { return }
            self.stopListening(status: "No command detected. Try saying blue pencil or red pen.")
        }
    }

    private func showStatus(_ message: String, autoHide: Bool) {
        statusDismissalTask?.cancel()
        statusDismissalTask = nil
        statusMessage = message
        isStatusVisible = true

        guard autoHide else { return }

        statusDismissalTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !self.isListening else { return }
            self.isStatusVisible = false
            self.transcript = ""
            self.audioLevel = 0
            self.audioLevels = Array(repeating: 0, count: self.audioLevels.count)
        }
    }

    private func smoothedAudioLevels(from levels: [CGFloat]) -> [CGFloat] {
        guard !levels.isEmpty else {
            return Array(repeating: 0, count: audioLevels.count)
        }

        return levels.enumerated().map { index, level in
            let previousLevel = index < audioLevels.count ? audioLevels[index] : 0
            let response: CGFloat = level > previousLevel ? 0.72 : 0.26
            return previousLevel + (level - previousLevel) * response
        }
    }
}

private final class SpeechAudioBufferAppender: @unchecked Sendable {
    private let request: SFSpeechAudioBufferRecognitionRequest

    init(request: SFSpeechAudioBufferRecognitionRequest) {
        self.request = request
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request.append(buffer)
    }
}

private extension AVAudioPCMBuffer {
    func normalizedAudioLevels(barCount: Int) -> [CGFloat] {
        guard
            let channelData = floatChannelData,
            frameLength > 0,
            format.channelCount > 0,
            barCount > 0
        else {
            return Array(repeating: 0, count: max(barCount, 0))
        }

        let sampleCount = Int(frameLength)
        return (0..<barCount).map { barIndex in
            let startSample = barIndex * sampleCount / barCount
            let endSample = max((barIndex + 1) * sampleCount / barCount, startSample + 1)
            return normalizedAudioLevel(in: startSample..<min(endSample, sampleCount), channelData: channelData)
        }
    }

    private func normalizedAudioLevel(
        in sampleRange: Range<Int>,
        channelData: UnsafePointer<UnsafeMutablePointer<Float>>
    ) -> CGFloat {
        let channelCount = Int(format.channelCount)
        let sampleStride = max(sampleRange.count / 36, 1)
        var squaredTotal: Float = 0
        var measuredSamples: Float = 0

        for channelIndex in 0..<channelCount {
            let samples = channelData[channelIndex]

            for sampleIndex in Swift.stride(from: sampleRange.lowerBound, to: sampleRange.upperBound, by: sampleStride) {
                let sample = samples[sampleIndex]
                squaredTotal += sample * sample
                measuredSamples += 1
            }
        }

        guard measuredSamples > 0 else { return 0 }

        let rms = sqrt(squaredTotal / measuredSamples)
        let decibels = 20 * log10(max(rms, 0.000_001))
        let normalized = (CGFloat(decibels) + 64) / 42
        return min(max(normalized, 0), 1)
    }
}
