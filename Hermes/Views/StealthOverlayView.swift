import SwiftUI

/// Compact, translucent copilot that lives in the stealth panel. Hidden from
/// screen sharing, so the user can jot follow-ups and ask private questions
/// mid-meeting without anyone else seeing.
struct StealthOverlayView: View {
    @ObservedObject private var model = StealthOverlayModel.shared
    @FocusState private var captureFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            captureField
            askSection

            if !model.captured.isEmpty {
                Divider().opacity(0.4)
                capturedList
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.28))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(hex: "D4AF37").opacity(0.35), lineWidth: 1)
            }
        )
        .onAppear { captureFocused = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "D4AF37"))

            VStack(alignment: .leading, spacing: 1) {
                Text("Hermes Copilot")
                    .font(.system(size: 13, weight: .semibold))
                Text("Hidden from screen share")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(model.hasActiveMeeting ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
                .help(model.hasActiveMeeting ? "Recording — follow-ups save to notes" : "No active meeting — captured to scratchpad")

            Button {
                StealthOverlayController.shared.hide()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Hide (⌃⌥⌘Space)")
        }
    }

    private var captureField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "D4AF37"))

                TextField("Follow up with… / anchor", text: $model.draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($captureFocused)
                    .onSubmit { model.capture() }

                Button(action: model.capture) {
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))
        }
    }

    private var askSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "D4AF37"))

                TextField("Ask the meeting privately…", text: $model.askText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit { model.ask() }

                if model.isAsking {
                    ProgressView().scaleEffect(0.5).frame(width: 16, height: 16)
                } else {
                    Button(action: model.ask) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color(hex: "D4AF37"))
                    .disabled(!model.hasCredential || model.askText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))

            if !model.hasCredential {
                Text("Add an AI credential in Settings to use private Q&A.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if !model.answer.isEmpty {
                ScrollView {
                    Text(model.answer)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 150)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
            }
        }
    }

    private var capturedList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CAPTURED")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)

            ForEach(model.captured.prefix(5)) { item in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: item.pushedToNotes ? "checkmark.circle.fill" : "tray.fill")
                        .font(.system(size: 10))
                        .foregroundColor(item.pushedToNotes ? .green : .secondary)
                    Text(item.text)
                        .font(.system(size: 11))
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Text(item.time)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield")
                .font(.system(size: 9))
            Text(model.hasActiveMeeting ? "Saving to live notes" : "Saving to scratchpad")
                .font(.system(size: 10))
            Spacer()
            Text("⌃⌥⌘Space")
                .font(.system(size: 9, design: .monospaced))
        }
        .foregroundColor(.secondary)
    }
}

#Preview {
    StealthOverlayView()
        .frame(width: 360, height: 440)
}

// MARK: - Hide any Hermes window from screen capture

/// Marks the hosting window as excluded from screen sharing / recording
/// (`NSWindow.sharingType = .none`). The window's pixels are never handed to
/// ScreenCaptureKit, Zoom, Meet, Teams, QuickTime, or screenshots.
extension View {
    func hiddenFromScreenCapture() -> some View {
        background(WindowCaptureHider())
    }
}

private struct WindowCaptureHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { CaptureHidingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class CaptureHidingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.sharingType = .none
    }
}
