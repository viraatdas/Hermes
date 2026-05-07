import AVFoundation
import Foundation
import Speech

@MainActor
class LiveTranscriptionService: ObservableObject {
    static let shared = LiveTranscriptionService()

    @Published private(set) var isRunning = false
    @Published var currentTranscript = ""
    @Published var lastError: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private init() {}

    func start() async {
        guard !isRunning else { return }

        do {
            try await ensureSpeechAuthorization()
            try startEngine()
            isRunning = true
            lastError = nil
        } catch {
            stop()
            lastError = error.localizedDescription
            print("Live transcription failed: \(error)")
        }
    }

    func stop() {
        guard isRunning || recognitionTask != nil || audioEngine.isRunning else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRunning = false
    }

    func reset() {
        currentTranscript = ""
        lastError = nil
    }

    private func ensureSpeechAuthorization() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard status == .authorized else {
            throw LiveTranscriptionError.notAuthorized
        }
    }

    private func startEngine() throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw LiveTranscriptionError.recognizerUnavailable
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    self?.currentTranscript = result.bestTranscription.formattedString
                }

                if let error {
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }
}

enum LiveTranscriptionError: Error, LocalizedError {
    case notAuthorized
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition permission is required for live meeting Q&A."
        case .recognizerUnavailable:
            return "Speech recognition is not available right now."
        }
    }
}

