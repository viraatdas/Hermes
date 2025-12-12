import Foundation
import Speech
import AVFoundation

@MainActor
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()
    
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0
    @Published var currentTranscript = ""
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    private init() {}
    
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        guard await requestAuthorization() else {
            throw TranscriptionError.notAuthorized
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        
        isTranscribing = true
        transcriptionProgress = 0
        currentTranscript = ""
        
        defer {
            isTranscribing = false
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        
        return try await withCheckedThrowingContinuation { continuation in
            var finalTranscript = ""
            
            recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result else { return }
                
                let transcript = result.bestTranscription.formattedString
                
                Task { @MainActor in
                    self?.currentTranscript = transcript
                }
                
                if result.isFinal {
                    finalTranscript = transcript
                    continuation.resume(returning: finalTranscript)
                }
            }
        }
    }
    
    func transcribeAndSave(audioURL: URL, outputURL: URL) async throws -> String {
        let transcript = try await transcribe(audioURL: audioURL)
        
        // Save transcript to file
        try transcript.write(to: outputURL, atomically: true, encoding: .utf8)
        
        return transcript
    }
}

enum TranscriptionError: Error, LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition not authorized"
        case .recognizerUnavailable: return "Speech recognizer unavailable"
        case .transcriptionFailed: return "Transcription failed"
        }
    }
}


