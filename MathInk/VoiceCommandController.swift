@preconcurrency import AVFoundation
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
    @Published var transcript = ""
    @Published var statusMessage = "Use the mic button or an Apple Pencil gesture, then say a command like blue pencil."

    var onCommand: ((InkCommand) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
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
            statusMessage = error.localizedDescription
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

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if let status {
            statusMessage = status
        }
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
        statusMessage = "Listening after \(trigger). Say something like red pen or yellow marker."

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
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { @Sendable buffer, _ in
            requestAppender.append(buffer)
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
