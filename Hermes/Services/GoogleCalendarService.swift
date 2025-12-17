import Foundation
import AuthenticationServices

@MainActor
class GoogleCalendarService: NSObject, ObservableObject {
    static let shared = GoogleCalendarService()
    
    // Google OAuth credentials are injected via Info.plist so we don't commit secrets.
    // Set these in Hermes/Info.plist (or inject during CI build).
    private var clientId: String {
        Bundle.main.object(forInfoDictionaryKey: "HERMES_GOOGLE_CLIENT_ID") as? String ?? ""
    }
    private var clientSecret: String {
        Bundle.main.object(forInfoDictionaryKey: "HERMES_GOOGLE_CLIENT_SECRET") as? String ?? ""
    }
    private let redirectURI = "http://127.0.0.1:8089/callback"
    private let scope = "https://www.googleapis.com/auth/calendar.readonly"
    
    @Published var isAuthenticated = false
    @Published var authError: String?
    @Published var isAuthenticating = false
    
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?
    
    private let keychainService = "com.hermes.googleauth"
    private var localServer: LocalAuthServer?
    
    private override init() {
        super.init()
        loadTokensFromKeychain()
    }
    
    // MARK: - OAuth Flow
    
    func authenticate() async throws {
        isAuthenticating = true
        authError = nil
        
        // Start local server to receive callback
        localServer = LocalAuthServer(port: 8089)
        
        do {
            try localServer?.start()
        } catch {
            isAuthenticating = false
            authError = "Failed to start auth server: \(error.localizedDescription)"
            throw AuthError.serverStartFailed
        }
        
        // Build auth URL
        let authURL = buildAuthURL()
        guard let url = URL(string: authURL) else {
            isAuthenticating = false
            throw AuthError.invalidURL
        }
        
        // Open browser for OAuth
        NSWorkspace.shared.open(url)
        
        // Wait for callback
        do {
            let code = try await localServer!.waitForCode()
            localServer?.stop()
            localServer = nil
            
            try await exchangeCodeForToken(code: code)
            isAuthenticating = false
        } catch {
            localServer?.stop()
            localServer = nil
            isAuthenticating = false
            authError = error.localizedDescription
            throw error
        }
    }
    
    private func buildAuthURL() -> String {
        guard !clientId.isEmpty else { return "" }
        let baseURL = "https://accounts.google.com/o/oauth2/v2/auth"
        var components = URLComponents(string: baseURL)!
        
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        return components.url!.absoluteString
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            throw AuthError.missingClientCredentials
        }
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]
        
        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&").data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Token exchange failed: \(errorBody)")
            throw AuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        accessToken = tokenResponse.access_token
        refreshToken = tokenResponse.refresh_token ?? refreshToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        
        saveTokensToKeychain()
        isAuthenticated = true
        
        // Trigger initial calendar sync immediately
        do {
            let meetings = try await fetchUpcomingMeetings()
            print("✅ Fetched \(meetings.count) meetings from Google Calendar")
            AppState.shared.upcomingMeetings = meetings
        } catch {
            print("❌ Failed to fetch calendar after auth: \(error)")
        }
    }
    
    private func refreshAccessToken() async throws {
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            throw AuthError.missingClientCredentials
        }
        guard let refreshToken = refreshToken else {
            throw AuthError.noRefreshToken
        }
        
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        accessToken = response.access_token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expires_in))
        
        saveTokensToKeychain()
    }
    
    // MARK: - Calendar API
    
    func fetchUpcomingMeetings() async throws -> [Meeting] {
        try await ensureValidToken()
        
        guard let accessToken = accessToken else {
            throw AuthError.notAuthenticated
        }
        
        // Get events for the next 14 days
        let now = ISO8601DateFormatter().string(from: Date())
        let endDate = ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: 14, to: Date())!)
        
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: now),
            URLQueryItem(name: "timeMax", value: endDate),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "50")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("📅 Fetching calendar events...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📅 Calendar API response: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
                print("❌ Calendar API error: \(errorBody)")
            }
        }
        
        let calendarResponse = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
        print("📅 Raw events count: \(calendarResponse.items?.count ?? 0)")
        
        let meetings = calendarResponse.items?.compactMap { event -> Meeting? in
            print("📅 Processing event: \(event.summary ?? "no title")")
            
            guard let id = event.id,
                  let title = event.summary else {
                print("  ❌ Missing id or title")
                return nil
            }
            
            let start = event.start?.dateTime ?? event.start?.date
            let end = event.end?.dateTime ?? event.end?.date
            
            guard let startStr = start, let endStr = end else {
                print("  ❌ Missing start/end time")
                return nil
            }
            
            print("  📅 Start: \(startStr), End: \(endStr)")
            
            let startDate = parseDate(startStr)
            let endDate = parseDate(endStr)
            
            print("  📅 Parsed start: \(String(describing: startDate)), end: \(String(describing: endDate))")
            
            // Extract meeting URL from various sources
            let meetingURL = event.hangoutLink ?? 
                           extractMeetingURL(from: event.description) ??
                           extractMeetingURL(from: event.location)
            
            print("  📅 Meeting URL: \(meetingURL ?? "none")")
            
            let meeting = Meeting(
                id: id,
                title: title,
                startTime: startDate ?? Date(),
                endTime: endDate ?? Date(),
                meetingURL: meetingURL,
                calendarId: "primary"
            )
            
            print("  ✅ Created meeting: \(meeting.title)")
            return meeting
        } ?? []
        
        print("📅 Final parsed meetings count: \(meetings.count)")
        return meetings
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            ISO8601DateFormatter(),
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // Try RFC 3339 format
        let rfc3339 = DateFormatter()
        rfc3339.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        if let date = rfc3339.date(from: dateString) {
            return date
        }
        
        // Try date-only format
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        return dateOnly.date(from: dateString)
    }
    
    private func extractMeetingURL(from text: String?) -> String? {
        guard let text = text else { return nil }
        
        let patterns = [
            "https://meet\\.google\\.com/[a-z-]+",
            "https://zoom\\.us/j/[0-9]+",
            "https://[a-z]+\\.zoom\\.us/j/[0-9]+",
            "https://teams\\.microsoft\\.com/l/meetup-join/[^\\s]+",
            "https://[a-z]+\\.webex\\.com/[^\\s]+"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                return String(text[Range(match.range, in: text)!])
            }
        }
        
        return nil
    }
    
    private func ensureValidToken() async throws {
        if let expiry = tokenExpiry, Date() >= expiry.addingTimeInterval(-60) {
            try await refreshAccessToken()
        }
    }
    
    // MARK: - Periodic Sync
    
    func startPeriodicSync() async {
        while true {
            if isAuthenticated {
                do {
                    let meetings = try await fetchUpcomingMeetings()
                    await MainActor.run {
                        AppState.shared.upcomingMeetings = meetings
                    }
                    
                    // Schedule notifications for upcoming meetings
                    await NotificationService.shared.scheduleNotifications(for: meetings)
                } catch {
                    print("Failed to sync calendar: \(error)")
                }
            }
            
            // Sync every 5 minutes
            try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
        }
    }
    
    // MARK: - Keychain
    
    private func saveTokensToKeychain() {
        let tokens = StoredTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiry: tokenExpiry
        )
        
        if let data = try? JSONEncoder().encode(tokens) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: "tokens"
            ]
            
            SecItemDelete(query as CFDictionary)
            
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }
    
    private func loadTokensFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "tokens",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let tokens = try? JSONDecoder().decode(StoredTokens.self, from: data) {
            accessToken = tokens.accessToken
            refreshToken = tokens.refreshToken
            tokenExpiry = tokens.expiry
            isAuthenticated = tokens.accessToken != nil
        }
    }
    
    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isAuthenticated = false
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "tokens"
        ]
        SecItemDelete(query as CFDictionary)
        
        AppState.shared.upcomingMeetings = []
    }
}

// MARK: - Local Auth Server

class LocalAuthServer {
    private let port: UInt16
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private var continuation: CheckedContinuation<String, Error>?
    
    init(port: UInt16) {
        self.port = port
    }
    
    func start() throws {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw AuthError.serverStartFailed
        }
        
        var reuse: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult >= 0 else {
            close(serverSocket)
            throw AuthError.serverStartFailed
        }
        
        guard listen(serverSocket, 1) >= 0 else {
            close(serverSocket)
            throw AuthError.serverStartFailed
        }
        
        isRunning = true
    }
    
    func waitForCode() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                var clientAddr = sockaddr_in()
                var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                
                let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                        accept(self.serverSocket, sockaddrPtr, &clientAddrLen)
                    }
                }
                
                guard clientSocket >= 0 else {
                    self.continuation?.resume(throwing: AuthError.serverStartFailed)
                    return
                }
                
                // Read HTTP request
                var buffer = [UInt8](repeating: 0, count: 4096)
                let bytesRead = read(clientSocket, &buffer, buffer.count)
                
                if bytesRead > 0 {
                    let requestString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
                    
                    // Parse the code from the request
                    if let code = self.parseCodeFromRequest(requestString) {
                        // Send success response
                        let successHTML = """
                        HTTP/1.1 200 OK\r
                        Content-Type: text/html\r
                        Connection: close\r
                        \r
                        <!DOCTYPE html>
                        <html>
                        <head>
                            <style>
                                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: linear-gradient(135deg, #FFB347, #FF6B35); }
                                .card { background: white; padding: 40px; border-radius: 16px; text-align: center; box-shadow: 0 10px 40px rgba(0,0,0,0.2); }
                                h1 { color: #FF6B35; margin: 0 0 10px 0; }
                                p { color: #666; margin: 0; }
                                .icon { font-size: 48px; margin-bottom: 20px; }
                            </style>
                        </head>
                        <body>
                            <div class="card">
                                <div class="icon">⚡</div>
                                <h1>Connected!</h1>
                                <p>Hermes is now connected to your Google Calendar.</p>
                                <p style="margin-top: 10px; font-size: 14px;">You can close this window.</p>
                            </div>
                        </body>
                        </html>
                        """
                        
                        _ = successHTML.withCString { ptr in
                            write(clientSocket, ptr, strlen(ptr))
                        }
                        
                        close(clientSocket)
                        self.continuation?.resume(returning: code)
                    } else {
                        // Send error response
                        let errorResponse = "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nNo authorization code found"
                        _ = errorResponse.withCString { ptr in
                            write(clientSocket, ptr, strlen(ptr))
                        }
                        close(clientSocket)
                        self.continuation?.resume(throwing: AuthError.noAuthCode)
                    }
                } else {
                    close(clientSocket)
                    self.continuation?.resume(throwing: AuthError.serverStartFailed)
                }
            }
        }
    }
    
    private func parseCodeFromRequest(_ request: String) -> String? {
        // Parse GET /callback?code=XXX HTTP/1.1
        guard let firstLine = request.components(separatedBy: "\r\n").first,
              let urlPart = firstLine.components(separatedBy: " ").dropFirst().first,
              let components = URLComponents(string: "http://localhost\(urlPart)"),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        return code
    }
    
    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }
}

// MARK: - Supporting Types

enum AuthError: Error, LocalizedError {
    case invalidURL
    case noAuthCode
    case noRefreshToken
    case notAuthenticated
    case tokenExchangeFailed
    case serverStartFailed
    case missingClientCredentials
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid authentication URL"
        case .noAuthCode: return "No authorization code received"
        case .noRefreshToken: return "No refresh token available"
        case .notAuthenticated: return "Not authenticated"
        case .tokenExchangeFailed: return "Failed to exchange token"
        case .serverStartFailed: return "Failed to start auth server"
        case .missingClientCredentials: return "Missing Google OAuth client credentials (HERMES_GOOGLE_CLIENT_ID / HERMES_GOOGLE_CLIENT_SECRET)"
        }
    }
}

struct TokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String?
    let token_type: String
}

struct StoredTokens: Codable {
    let accessToken: String?
    let refreshToken: String?
    let expiry: Date?
}

struct CalendarEventsResponse: Codable {
    let items: [CalendarEvent]?
}

struct CalendarEvent: Codable {
    let id: String?
    let summary: String?
    let description: String?
    let location: String?
    let start: EventDateTime?
    let end: EventDateTime?
    let hangoutLink: String?
}

struct EventDateTime: Codable {
    let dateTime: String?
    let date: String?
}
