import SwiftUI

/// Game Boy Color-inspired shell around the game screen
struct GameBoyShell: View {
    @ObservedObject var renderer: FrameRenderer
    @ObservedObject var appState: AppState
    @ObservedObject var toolbarState: ToolbarState
    var keyBindings: KeyBindings?
    var onBack: () -> Void
    var onSettings: () -> Void

    private let shellColor = Color(red: 0.45, green: 0.30, blue: 0.65) // GBC purple
    private let shellDark = Color(red: 0.35, green: 0.22, blue: 0.52)
    private let screenBezel = Color(red: 0.25, green: 0.25, blue: 0.30)

    var body: some View {
        VStack(spacing: 0) {
            // Top label
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Back to Library")

                Spacer()

                Text("CrystalBoy")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(2)

                Spacer()

                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Screen bezel
            VStack(spacing: 0) {
                // Power indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(toolbarState.isPaused ? Color.red : Color.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: toolbarState.isPaused ? .red : .green, radius: 3)
                    Text(toolbarState.isPaused ? "PAUSED" : "POWER")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.gray)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)

                // Game screen
                ZStack {
                    GameView(renderer: renderer)

                    // Help overlay
                    if appState.showHelp {
                        helpOverlay
                    }

                    // Toast
                    if let toast = appState.toastMessage {
                        VStack {
                            Spacer()
                            Text(toast)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.75))
                                .cornerRadius(4)
                                .padding(.bottom, 8)
                        }
                        .allowsHitTesting(false)
                    }
                }
                .aspectRatio(CGFloat(renderer.screenWidth) / CGFloat(max(1, renderer.screenHeight)), contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .background(screenBezel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)

            // Controls area
            HStack(spacing: 0) {
                // Left: Save/Load
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        shellButton("SAVE", icon: "square.and.arrow.down") {
                            toolbarState.onSave?()
                        }
                        shellButton("LOAD", icon: "square.and.arrow.up") {
                            toolbarState.onLoad?()
                        }
                    }
                    HStack(spacing: 4) {
                        slotButton("◀") { toolbarState.onPrevSlot?() }
                        Text("Slot \(toolbarState.currentSlot)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 40)
                        slotButton("▶") { toolbarState.onNextSlot?() }
                    }
                }
                .frame(maxWidth: .infinity)

                // Center: Pause
                Button(action: { toolbarState.onTogglePause?() }) {
                    VStack(spacing: 2) {
                        Image(systemName: toolbarState.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 16))
                        Text(toolbarState.isPaused ? "PLAY" : "PAUSE")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 50, height: 44)
                    .background(shellDark)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Right: Speed (percentage based, 5% steps)
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.medium")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(speedLabel)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(toolbarState.speed == 1.0 ? .white.opacity(0.5) : .cyan)
                    }
                    Slider(value: $toolbarState.speed, in: 0.25...4.0, step: 0.05)
                        .tint(.cyan)
                        .frame(width: 120)
                        .onChange(of: toolbarState.speed) { _, val in
                            toolbarState.onSpeedChanged?(val)
                        }
                    if toolbarState.speed != 1.0 {
                        Button("Reset to 100%") {
                            toolbarState.speed = 1.0
                            toolbarState.onSpeedChanged?(1.0)
                        }
                        .font(.system(size: 9))
                        .buttonStyle(.plain)
                        .foregroundStyle(.cyan.opacity(0.7))
                    }
                    // Volume
                    HStack(spacing: 4) {
                        Button(action: { toolbarState.onToggleMute?() }) {
                            Image(systemName: volumeIcon)
                                .font(.system(size: 10))
                                .foregroundStyle(toolbarState.isMuted ? .red.opacity(0.6) : .white.opacity(0.4))
                        }
                        .buttonStyle(.plain)

                        Text(volumeLabel)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(toolbarState.isMuted ? .red.opacity(0.5) : .white.opacity(0.5))
                    }
                    Slider(value: $toolbarState.volume, in: 0...1, step: 0.1)
                        .tint(toolbarState.isMuted ? .red.opacity(0.5) : .green)
                        .frame(width: 120)
                        .onChange(of: toolbarState.volume) { _, val in
                            toolbarState.onVolumeChanged?(val)
                        }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Bottom: "Hold H for controls" hint
            Text("Hold H for all controls")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [shellColor, shellDark],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
    }

    private var speedLabel: String {
        "\(Int(round(toolbarState.speed * 100)))%"
    }

    private var volumeIcon: String {
        if toolbarState.isMuted { return "speaker.slash.fill" }
        if toolbarState.volume == 0 { return "speaker.fill" }
        if toolbarState.volume < 0.5 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    private var volumeLabel: String {
        toolbarState.isMuted ? "MUTE" : "\(Int(round(toolbarState.volume * 100)))%"
    }

    private func shellButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.6))
            .frame(width: 44, height: 36)
            .background(shellDark.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func slotButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 20, height: 16)
                .background(shellDark.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }

    // Help overlay (same as before)
    private var helpOverlay: some View {
        VStack(spacing: 12) {
            Text("CONTROLS")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    helpSection("Game Buttons", category: .gameButtons)
                    Spacer().frame(height: 8)
                    helpSection("Speed", category: .speed)
                }
                VStack(alignment: .leading, spacing: 4) {
                    helpSection("Save & Load", category: .saveLoad)
                    Spacer().frame(height: 8)
                    helpSection("Volume", category: .volume)
                    Spacer().frame(height: 8)
                    helpSection("Emulator", category: .emulator)
                }
            }

            Text("Release H to close")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .padding(20)
        .background(Color.black.opacity(0.92))
        .cornerRadius(12)
    }

    private func helpSection(_ title: String, category: ActionCategory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.yellow)
            let actions = EmulatorAction.actions(for: category)
            ForEach(0..<actions.count, id: \.self) { i in
                HStack(spacing: 8) {
                    Text(actions[i].defaultKeyName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .frame(width: 60, alignment: .trailing)
                    Text(actions[i].displayName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

/// Observable state shared between GameToolbar and GameSession
final class ToolbarState: ObservableObject {
    @Published var isPaused = false
    @Published var speed: Float = 1.0
    @Published var currentSlot = 0

    var onTogglePause: (() -> Void)?
    var onSave: (() -> Void)?
    var onLoad: (() -> Void)?
    var onPrevSlot: (() -> Void)?
    var onNextSlot: (() -> Void)?
    var onSpeedChanged: ((Float) -> Void)?

    @Published var volume: Float = 1.0
    @Published var isMuted = false

    var onVolumeChanged: ((Float) -> Void)?
    var onToggleMute: (() -> Void)?
}
