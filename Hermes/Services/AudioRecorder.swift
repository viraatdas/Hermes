import Foundation
import AVFoundation
import ScreenCaptureKit

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorder()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    
    private var recordingURL: URL?
    private var startTime: Date?
    private var timer: Timer?
    
    private var stream: SCStream?
    private var audioWriter: WavAudioWriter?
    
    private override init() {
        super.init()
    }
    
    func startRecording(meetingTitle: String) async throws -> URL {
        if isRecording {
            _ = try? await stopRecording()
        }
        
        await cleanup()
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let hermesURL = documentsURL.appendingPathComponent("Hermes/Recordings")
        try fileManager.createDirectory(at: hermesURL, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        
        let sanitizedTitle = meetingTitle.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        let fileName = "\(sanitizedTitle)_\(dateString).wav"
        let fileURL = hermesURL.appendingPathComponent(fileName)
        
        recordingURL = fileURL
        
        try await startAudioCapture(outputURL: fileURL)
        
        isRecording = true
        startTime = Date()
        startTimer()
        
        return fileURL
    }
    
    private func cleanup() async {
        if let stream = stream {
            try? await stream.stopCapture()
        }
        stream = nil
        audioWriter?.stop()
        audioWriter = nil
    }
    
    private func startAudioCapture(outputURL: URL) async throws {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = availableContent.displays.first else {
            throw RecordingError.noDisplayAvailable
        }
        
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = false
        configuration.sampleRate = 48000
        configuration.channelCount = 2
        
        if #available(macOS 15.0, *) {
            configuration.captureMicrophone = true
            configuration.microphoneCaptureDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID
        }
        
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 10, timescale: 1)
        configuration.showsCursor = false
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        audioWriter = WavAudioWriter(outputURL: outputURL)
        
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        
        guard let stream = stream, let audioWriter = audioWriter else {
            throw RecordingError.streamCreationFailed
        }
        
        try stream.addStreamOutput(audioWriter, type: .audio, sampleHandlerQueue: DispatchQueue(label: "audio"))
        try stream.addStreamOutput(audioWriter, type: .screen, sampleHandlerQueue: DispatchQueue(label: "screen"))
        
        if #available(macOS 15.0, *) {
            try stream.addStreamOutput(audioWriter, type: .microphone, sampleHandlerQueue: DispatchQueue(label: "mic"))
        }
        
        try await stream.startCapture()
        print("📼 Recording started")
    }
    
    func stopRecording() async throws -> URL? {
        guard isRecording else { return nil }
        
        stopTimer()
        isRecording = false
        
        if let stream = stream {
            try? await stream.stopCapture()
        }
        stream = nil
        
        audioWriter?.stop()
        audioWriter = nil
        
        let url = recordingURL
        recordingURL = nil
        
        if let url = url {
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            print("📼 Recording saved: \(size) bytes")
        }
        
        return url
    }
    
    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        startTime = nil
    }
    
    var formattedDuration: String {
        let minutes = Int(recordingDuration / 60)
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - WAV Audio Writer

class WavAudioWriter: NSObject, SCStreamOutput {
    private let outputURL: URL
    private var audioFile: AVAudioFile?
    private var isSetup = false
    private let lock = NSLock()
    
    init(outputURL: URL) {
        self.outputURL = outputURL
        super.init()
    }
    
    func stop() {
        lock.lock()
        audioFile = nil
        isSetup = false
        lock.unlock()
        print("📼 Audio file closed")
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        var isAudio = (type == .audio)
        if #available(macOS 15.0, *) {
            if type == .microphone { isAudio = true }
        }
        guard isAudio else { return }
        
        guard CMSampleBufferIsValid(sampleBuffer),
              CMSampleBufferDataIsReady(sampleBuffer),
              CMSampleBufferGetNumSamples(sampleBuffer) > 0 else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        // Get format info
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            return
        }
        
        // Setup audio file on first buffer
        if !isSetup {
            try? FileManager.default.removeItem(at: outputURL)
            
            // Create format matching the input
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: asbd.mSampleRate,
                channels: AVAudioChannelCount(asbd.mChannelsPerFrame),
                interleaved: false
            ) else { return }
            
            do {
                audioFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
                isSetup = true
                print("📼 Audio file created: \(asbd.mSampleRate)Hz, \(asbd.mChannelsPerFrame)ch")
            } catch {
                print("❌ Failed to create audio file: \(error)")
                return
            }
        }
        
        // Convert and write
        guard let pcmBuffer = convertToPCMBuffer(sampleBuffer: sampleBuffer, asbd: asbd) else { return }
        
        do {
            try audioFile?.write(from: pcmBuffer)
        } catch {
            print("❌ Write error: \(error)")
        }
    }
    
    private func convertToPCMBuffer(sampleBuffer: CMSampleBuffer, asbd: AudioStreamBasicDescription) -> AVAudioPCMBuffer? {
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        let channels = Int(asbd.mChannelsPerFrame)
        
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: asbd.mSampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        ) else { return nil }
        
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == kCMBlockBufferNoErr,
              let dataPointer = dataPointer else {
            return nil
        }
        
        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let isInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
        
        if isFloat {
            let floatPtr = UnsafeRawPointer(dataPointer).bindMemory(to: Float.self, capacity: frameCount * channels)
            
            if isInterleaved {
                for frame in 0..<frameCount {
                    for ch in 0..<channels {
                        pcmBuffer.floatChannelData?[ch][frame] = floatPtr[frame * channels + ch]
                    }
                }
            } else {
                for ch in 0..<channels {
                    for frame in 0..<frameCount {
                        pcmBuffer.floatChannelData?[ch][frame] = floatPtr[ch * frameCount + frame]
                    }
                }
            }
        } else {
            // Integer format - convert to float
            let bytesPerSample = Int(asbd.mBitsPerChannel / 8)
            
            if bytesPerSample == 2 {
                let int16Ptr = UnsafeRawPointer(dataPointer).bindMemory(to: Int16.self, capacity: frameCount * channels)
                for frame in 0..<frameCount {
                    for ch in 0..<channels {
                        let sample = int16Ptr[frame * channels + ch]
                        pcmBuffer.floatChannelData?[ch][frame] = Float(sample) / 32768.0
                    }
                }
            } else if bytesPerSample == 4 {
                let int32Ptr = UnsafeRawPointer(dataPointer).bindMemory(to: Int32.self, capacity: frameCount * channels)
                for frame in 0..<frameCount {
                    for ch in 0..<channels {
                        let sample = int32Ptr[frame * channels + ch]
                        pcmBuffer.floatChannelData?[ch][frame] = Float(sample) / Float(Int32.max)
                    }
                }
            }
        }
        
        return pcmBuffer
    }
}

enum RecordingError: Error, LocalizedError {
    case alreadyRecording, noDisplayAvailable, streamCreationFailed, engineCreationFailed, notRecording
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording: return "Already recording"
        case .noDisplayAvailable: return "No display available"
        case .streamCreationFailed: return "Failed to create stream"
        case .engineCreationFailed: return "Failed to create engine"
        case .notRecording: return "Not recording"
        }
    }
}
