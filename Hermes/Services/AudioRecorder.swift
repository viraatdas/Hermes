import Foundation
import AVFoundation
import ScreenCaptureKit

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorder()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var systemAudioURL: URL?
    private var startTime: Date?
    private var timer: Timer?
    
    // System audio monitoring (for silence detection)
    private var systemAudioMonitor: SystemAudioMonitor?
    
    // Silence detection
    private var lastAudioTime: Date = Date()
    private var silenceCheckTimer: Timer?
    private let silenceThreshold: Float = 0.005
    private let silenceDurationForAutoStop: TimeInterval = 5 * 60 // 5 minutes
    
    private override init() {
        super.init()
    }
    
    func startRecording(meetingTitle: String) async throws -> URL {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }

        // Ensure we have microphone permission before creating the engine.
        // Without this, macOS can yield silent/empty recordings.
        try await ensureMicrophonePermission()
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let hermesURL = documentsURL.appendingPathComponent("Hermes/Recordings")
        
        try fileManager.createDirectory(at: hermesURL, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        
        let sanitizedTitle = meetingTitle.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        let fileName = "\(sanitizedTitle)_\(dateString).m4a"
        let fileURL = hermesURL.appendingPathComponent(fileName)
        
        recordingURL = fileURL
        systemAudioURL = nil
        
        // Start microphone recording
        try startMicrophoneRecording(outputURL: fileURL)
        
        // Start system audio capture (best-effort; requires Screen Recording permission)
        let systemURL = fileURL.deletingPathExtension().appendingPathExtension("system.caf")
        systemAudioURL = systemURL
        await startSystemAudioMonitoring(outputURL: systemURL)
        
        isRecording = true
        startTime = Date()
        lastAudioTime = Date()
        startTimer()
        startSilenceMonitoring()
        
        print("🎙️ Recording started: \(fileName)")
        
        return fileURL
    }

    private func ensureMicrophonePermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { ok in
                    continuation.resume(returning: ok)
                }
            }
            if !granted {
                throw RecordingError.microphonePermissionDenied
            }
        case .denied, .restricted:
            throw RecordingError.microphonePermissionDenied
        @unknown default:
            throw RecordingError.microphonePermissionDenied
        }
    }
    
    private func startMicrophoneRecording(outputURL: URL) throws {
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        // Record microphone audio directly to AAC-in-M4A.
        // This is much more reliable on macOS than trying to write compressed formats via AVAudioFile.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw RecordingError.engineCreationFailed
        }

        audioRecorder = recorder
        print("🎙️ Microphone recording started (m4a, 44.1kHz, mono)")
    }
    
    private func startSystemAudioMonitoring(outputURL: URL) async {
        systemAudioMonitor = SystemAudioMonitor(outputURL: outputURL)
        systemAudioMonitor?.onAudioDetected = { [weak self] in
            // System audio detected - reset silence timer
            self?.lastAudioTime = Date()
        }
        
        do {
            try await systemAudioMonitor?.start()
            print("🔊 System audio capture started")
        } catch {
            print("⚠️ System audio monitoring failed: \(error.localizedDescription)")
            // Continue without system audio monitoring - mic recording still works
        }
    }
    
    func stopRecording() async throws -> URL? {
        guard isRecording else {
            return nil
        }
        
        print("🛑 Stopping recording...")
        
        stopTimer()
        stopSilenceMonitoring()
        isRecording = false
        
        // Stop system audio monitoring
        await systemAudioMonitor?.stop()
        systemAudioMonitor = nil
        
        // Stop microphone recording
        audioRecorder?.stop()
        audioRecorder = nil
        
        let micURL = recordingURL
        recordingURL = nil
        let sysURL = systemAudioURL
        systemAudioURL = nil

        var finalURL = micURL
        if let micURL, let sysURL {
            // Only attempt a mix if system audio actually produced data.
            let sysSize = (try? FileManager.default.attributesOfItem(atPath: sysURL.path)[.size] as? Int64) ?? 0
            if sysSize > 4096 {
                if let mixed = try? await mixAudio(micURL: micURL, systemURL: sysURL) {
                    finalURL = mixed
                }
            }
        }
        
        // Verify file was created
        if let url = finalURL {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                let size = attributes?[.size] as? Int64 ?? 0
                print("✅ Recording saved: \(url.lastPathComponent) (\(size) bytes)")
            } else {
                print("⚠️ Recording file not found at expected path")
            }
        }
        
        return finalURL
    }
    
    private func mixAudio(micURL: URL, systemURL: URL) async throws -> URL {
        let micAsset = AVURLAsset(url: micURL)
        let sysAsset = AVURLAsset(url: systemURL)

        let composition = AVMutableComposition()
        guard
            let compMicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
            let compSysTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw RecordingError.mixFailed
        }

        let micTracks = try await micAsset.loadTracks(withMediaType: .audio)
        let sysTracks = try await sysAsset.loadTracks(withMediaType: .audio)
        guard let micTrack = micTracks.first, let sysTrack = sysTracks.first else {
            throw RecordingError.mixFailed
        }

        let micDur = try await micAsset.load(.duration)
        let sysDur = try await sysAsset.load(.duration)
        let duration = CMTimeMaximum(micDur, sysDur)
        let range = CMTimeRange(start: .zero, duration: duration)

        try compMicTrack.insertTimeRange(range, of: micTrack, at: .zero)
        try compSysTrack.insertTimeRange(range, of: sysTrack, at: .zero)

        let outURL = micURL.deletingPathExtension().appendingPathExtension("mix.m4a")
        try? FileManager.default.removeItem(at: outURL)

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw RecordingError.mixFailed
        }
        export.outputURL = outURL
        export.outputFileType = .m4a
        export.timeRange = range

        return try await withCheckedThrowingContinuation { continuation in
            export.exportAsynchronously { [weak export] in
                guard let export else {
                    continuation.resume(throwing: RecordingError.mixFailed)
                    return
                }
                switch export.status {
                case .completed:
                    continuation.resume(returning: outURL)
                case .failed:
                    continuation.resume(throwing: export.error ?? RecordingError.mixFailed)
                case .cancelled:
                    continuation.resume(throwing: RecordingError.mixFailed)
                default:
                    continuation.resume(throwing: RecordingError.mixFailed)
                }
            }
        }
    }

    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.startTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)

                // Metering + simple silence detection
                self.audioRecorder?.updateMeters()
                if let db = self.audioRecorder?.averagePower(forChannel: 0) {
                    let linear = pow(10.0, db / 20.0)
                    let level = Float(linear)
                    self.audioLevel = level
                    if level > self.silenceThreshold {
                        self.lastAudioTime = Date()
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        startTime = nil
    }
    
    private func startSilenceMonitoring() {
        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSilence()
            }
        }
    }
    
    private func stopSilenceMonitoring() {
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil
    }
    
    private func checkSilence() {
        let silenceDuration = Date().timeIntervalSince(lastAudioTime)
        if silenceDuration >= silenceDurationForAutoStop {
            print("🔇 Silence detected for \(Int(silenceDuration))s, auto-stopping recording")
            Task { @MainActor in
                await MeetingManager.shared.stopRecording()
            }
        }
    }
    
    var formattedDuration: String {
        let minutes = Int(recordingDuration / 60)
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - System Audio Monitor (ScreenCaptureKit)

class SystemAudioMonitor: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var isMonitoring = false
    private let outputURL: URL
    private var audioFile: AVAudioFile?
    private let writeQueue = DispatchQueue(label: "com.hermes.systemAudio.write", qos: .utility)
    
    var onAudioDetected: (() -> Void)?

    init(outputURL: URL) {
        self.outputURL = outputURL
        super.init()
    }
    
    func start() async throws {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        
        guard let display = availableContent.displays.first else {
            throw RecordingError.engineCreationFailed
        }
        
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.channelCount = 2
        configuration.sampleRate = 48000
        
        // Minimal video (required but unused)
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        
        guard let stream = stream else {
            throw RecordingError.engineCreationFailed
        }

        // Create a PCM CAF file for system audio (reliable; we'll mix later).
        try? FileManager.default.removeItem(at: outputURL)
        audioFile = nil

        let queue = writeQueue
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        
        try await stream.startCapture()
        isMonitoring = true
    }
    
    func stop() async {
        isMonitoring = false
        if let stream = stream {
            try? await stream.stopCapture()
            self.stream = nil
        }
    }
    
    // MARK: - SCStreamOutput
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isMonitoring else { return }
        guard type == .audio else { return }

        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        guard let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return }

        guard let format = AVAudioFormat(streamDescription: asbdPtr) else { return }

        // Lazily create the output file once we know the exact format.
        if audioFile == nil {
            let isFloat = (asbdPtr.pointee.mFormatFlags & kAudioFormatFlagIsFloat) != 0
            let isNonInterleaved = (asbdPtr.pointee.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0
            let bitDepth = Int(asbdPtr.pointee.mBitsPerChannel)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: asbdPtr.pointee.mSampleRate,
                AVNumberOfChannelsKey: Int(asbdPtr.pointee.mChannelsPerFrame),
                AVLinearPCMBitDepthKey: bitDepth > 0 ? bitDepth : 32,
                AVLinearPCMIsFloatKey: isFloat,
                AVLinearPCMIsNonInterleaved: isNonInterleaved
            ]
            do {
                audioFile = try AVAudioFile(forWriting: outputURL, settings: settings)
            } catch {
                return
            }
        }

        guard let pcmBuffer = makePCMBuffer(from: sampleBuffer, format: format) else { return }
        
        // Check if there's audio activity
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
        
        guard status == kCMBlockBufferNoErr, let data = dataPointer, length > 0 else { return }
        
        // Calculate RMS to detect audio activity
        let sampleCount = length / MemoryLayout<Float>.size
        guard sampleCount > 0 else { return }
        
        let samples = UnsafeRawPointer(data).assumingMemoryBound(to: Float.self)
        var sum: Float = 0
        
        let checkCount = min(sampleCount, 1000)
        for i in 0..<checkCount {
            let sample = samples[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(checkCount))
        
        // If audio level is above threshold, notify
        if rms > 0.001 {
            onAudioDetected?()
        }

        do {
            try audioFile?.write(from: pcmBuffer)
        } catch {
            // swallow; keep capture running
        }
    }

    private func makePCMBuffer(from sampleBuffer: CMSampleBuffer, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        var blockBuffer: CMBlockBuffer?

        let maxBuffers = 2
        let ablSize = MemoryLayout<AudioBufferList>.size + (maxBuffers - 1) * MemoryLayout<AudioBuffer>.size
        let ablPtr = UnsafeMutableRawPointer.allocate(byteCount: ablSize, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { ablPtr.deallocate() }
        let audioBufferList = ablPtr.bindMemory(to: AudioBufferList.self, capacity: 1)

        var outSize = ablSize
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &outSize,
            bufferListOut: audioBufferList,
            bufferListSize: ablSize,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return nil }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        pcm.frameLength = frameCount

        let srcABL = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let dstABL = UnsafeMutableAudioBufferListPointer(pcm.mutableAudioBufferList)

        let bufferCount = min(srcABL.count, dstABL.count)
        for i in 0..<bufferCount {
            guard let srcData = srcABL[i].mData, let dstData = dstABL[i].mData else { continue }
            memcpy(dstData, srcData, Int(min(srcABL[i].mDataByteSize, dstABL[i].mDataByteSize)))
        }

        return pcm
    }
}

// MARK: - Errors

enum RecordingError: Error, LocalizedError {
    case alreadyRecording
    case engineCreationFailed
    case notRecording
    case microphonePermissionDenied
    case mixFailed
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording: return "Already recording"
        case .engineCreationFailed: return "Failed to create audio engine - check microphone permissions"
        case .notRecording: return "Not currently recording"
        case .microphonePermissionDenied: return "Microphone access denied. Enable it in System Settings → Privacy & Security → Microphone."
        case .mixFailed: return "Failed to combine microphone + system audio"
        }
    }
}
