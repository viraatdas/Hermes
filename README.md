# Hermes: Discrete Meeting Notetaker

A native macOS menu bar app that records your meetings with one-click join, automatic transcription, and smart calendar integration.

![macOS 14+](https://img.shields.io/badge/macOS-14+-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
[![CI](https://github.com/viraatdas/Hermes/actions/workflows/ci.yml/badge.svg)](https://github.com/viraatdas/Hermes/actions/workflows/ci.yml)
[![Release DMG](https://github.com/viraatdas/Hermes/actions/workflows/release.yml/badge.svg)](https://github.com/viraatdas/Hermes/actions/workflows/release.yml)

## Features

- **One-click join & record** - Click to join meetings and automatically start recording
- **Records both sides** - Captures system audio (meeting participants) AND your microphone
- **Automatic transcription** - Uses Apple's on-device Speech framework
- **Invisible copilot overlay** - A floating panel hidden from screen sharing (`⌃⌥⌘Space`). Capture follow-ups and ask the transcript privately mid-call — nobody else sees it
- **Anchors → Notes** - Jot short anchors while staying present; Hermes merges them with the transcript into a clean summary, decisions, and action items you can chat with
- **Bring your own AI** - Anthropic API key, Claude Code OAuth token, or Codex / OpenAI key. Import an existing CLI login from `~/.claude/.credentials.json` or `~/.codex/auth.json`. Stored in the macOS Keychain
- **Google Calendar integration** - See upcoming meetings with video links
- **MCP server** - Claude Desktop, Cursor, and Claude Code can search, read, and enrich your notes as tools
- **Smart notifications** - Get reminders only for meetings with video calls
- **Export as M4A** - High-quality audio exports

## Quick Start

### 1. Clone & Open

```bash
git clone https://github.com/YOUR_USERNAME/Hermes.git
cd Hermes
open Hermes.xcodeproj
```

### 2. Configure Google Calendar API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Google Calendar API**
4. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
5. Select **Desktop app** as the application type
6. Download the credentials

### 3. Add Your Credentials

Set these keys in `Hermes/Info.plist`:

- `HERMES_GOOGLE_CLIENT_ID`
- `HERMES_GOOGLE_CLIENT_SECRET`

### 4. Build & Run

1. Select your signing team in Xcode (Signing & Capabilities)
2. Build and run (⌘R)
3. Grant permissions when prompted:
   - **Microphone** - For recording your voice
   - **Screen Recording** - For capturing meeting audio
   - **Notifications** - For meeting reminders

## Usage

### Menu Bar
The app lives in your menu bar:
- 🟠 Normal state
- 🔴 Recording state

### Connecting Calendar
1. Click the menu bar icon
2. Click "Connect" to sign in with Google
3. Your meetings will appear automatically

### Recording a Meeting
1. Hover over any meeting with a video link and click "Join"
2. The meeting opens in your browser AND recording starts automatically
3. Click "Stop Recording" when done
4. Transcription begins automatically in the background

### From Notifications
- When a meeting is starting, you'll get a notification
- Click "Join & Record" to join and start recording instantly

## Architecture

```
Hermes/
├── HermesApp.swift              # App entry point & delegate
├── Models/
│   ├── AppState.swift           # Global app state
│   └── Meeting.swift            # Meeting data models
├── Services/
│   ├── GoogleCalendarService.swift   # Calendar OAuth & API
│   ├── NotificationService.swift     # Meeting reminders
│   ├── AudioRecorder.swift           # System + mic audio capture
│   ├── TranscriptionService.swift    # Speech-to-text
│   ├── ScreenShareDetector.swift     # Screen share detection
│   └── MeetingManager.swift          # Recording orchestration
└── Views/
    ├── MenuBarView.swift             # Menu bar dropdown
    ├── CalendarView.swift            # Calendar window
    ├── SettingsView.swift            # Preferences
    └── MeetingHistoryView.swift      # Past recordings
```

## Technical Details

### Audio Recording
- Uses **ScreenCaptureKit** to capture system audio (what you hear from the meeting)
- Uses **AVAudioRecorder** to capture microphone audio (your voice)
- Both streams are mixed together into a single recording
- Records in **M4A format** (AAC codec) for quality and compatibility

### Transcription
- Uses Apple's **Speech framework** (on-device, private)
- Automatic punctuation
- No data sent to external servers

### Data Storage
- Recordings: `~/Documents/Hermes/Recordings/`
- Metadata: `~/Documents/Hermes/metadata.json`
- Tokens: Securely stored in **Keychain**

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Google account for calendar integration

## Permissions

| Permission | Purpose |
|------------|---------|
| Microphone | Record your voice |
| Screen Recording | Capture meeting audio |
| Notifications | Meeting reminders |

## Privacy

- All recordings are stored locally on your Mac
- Transcription is done on-device using Apple's Speech framework
- No audio data is sent to external servers
- Google Calendar access is read-only

## License

MIT
