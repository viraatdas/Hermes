import Foundation

struct Meeting: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let meetingURL: String?
    let calendarId: String?
    
    var timeUntilStart: TimeInterval {
        startTime.timeIntervalSinceNow
    }
    
    var isStartingSoon: Bool {
        let minutes = timeUntilStart / 60
        return minutes > 0 && minutes <= 5
    }
    
    var isInProgress: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    var formattedCountdown: String {
        let minutes = Int(timeUntilStart / 60)
        let seconds = Int(timeUntilStart) % 60
        
        if minutes > 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else if seconds > 0 {
            return "\(seconds)s"
        } else {
            return "Now"
        }
    }
}

struct RecordedMeeting: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let date: Date
    let duration: TimeInterval
    let audioFilePath: String
    var transcriptFilePath: String?
    var transcript: String?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var audioURL: URL? {
        URL(fileURLWithPath: audioFilePath)
    }
}

