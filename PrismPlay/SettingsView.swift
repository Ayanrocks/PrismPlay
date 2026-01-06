import SwiftUI

struct SettingsView: View {
    @ObservedObject private var appSettings = AppSettings.shared
    @ObservedObject private var playerSettings = PlayerSettings.shared
    @State private var showResetConfirmation = false
    
    var body: some View {
        ZStack {
            // Background
            PrismBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    Text("Settings")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    // Appearance Section
                    SettingsSection(title: "Appearance", icon: "paintbrush.fill") {
                        SettingsRow(title: "Theme", icon: appSettings.colorScheme.iconName) {
                            Picker("", selection: Binding(
                                get: { appSettings.colorScheme },
                                set: { appSettings.colorScheme = $0 }
                            )) {
                                ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                                    Text(scheme.displayName).tag(scheme)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                        
                        SettingsToggleRow(
                            title: "Use System Theme",
                            icon: "gear",
                            isOn: $appSettings.useSystemTheme
                        )
                    }
                    
                    // Playback Controls Section
                    SettingsSection(title: "Playback Controls", icon: "play.circle.fill") {
                        SettingsSliderRow(
                            title: "Double-Tap Seek",
                            icon: "hand.tap.fill",
                            value: $playerSettings.doubleTapSeekSeconds,
                            range: 5...30,
                            step: 5,
                            unit: "sec"
                        )
                        
                        SettingsSliderRow(
                            title: "Skip Button",
                            icon: "forward.fill",
                            value: $playerSettings.skipButtonSeconds,
                            range: 5...60,
                            step: 5,
                            unit: "sec"
                        )
                        
                        SettingsSliderRow(
                            title: "Flick Seek",
                            icon: "hand.draw.fill",
                            value: $playerSettings.flickSeekSeconds,
                            range: 5...30,
                            step: 5,
                            unit: "sec"
                        )
                        
                        SettingsSliderRow(
                            title: "Controls Auto-Hide",
                            icon: "eye.slash.fill",
                            value: $playerSettings.controlsAutoHideDelay,
                            range: 2...10,
                            step: 1,
                            unit: "sec"
                        )
                        
                        SettingsToggleRow(
                            title: "Resume Playback",
                            subtitle: "Continue from last position",
                            icon: "arrow.counterclockwise",
                            isOn: $playerSettings.resumePlaybackAutomatically
                        )
                        
                        SettingsToggleRow(
                            title: "Remember Speed",
                            subtitle: "Keep last playback speed",
                            icon: "speedometer",
                            isOn: $playerSettings.rememberPlaybackSpeed
                        )
                    }
                    
                    // Gestures Section
                    SettingsSection(title: "Gestures", icon: "hand.raised.fill") {
                        SettingsToggleRow(
                            title: "Brightness Gesture",
                            subtitle: "Swipe on left side",
                            icon: "sun.max.fill",
                            isOn: $playerSettings.brightnessGestureEnabled
                        )
                        
                        SettingsToggleRow(
                            title: "Volume Gesture",
                            subtitle: "Swipe on right side",
                            icon: "speaker.wave.3.fill",
                            isOn: $playerSettings.volumeGestureEnabled
                        )
                        
                        SettingsToggleRow(
                            title: "Seek Gesture",
                            subtitle: "Horizontal swipe to seek",
                            icon: "arrow.left.and.right",
                            isOn: $playerSettings.seekGestureEnabled
                        )
                        
                        SettingsToggleRow(
                            title: "Double-Tap to Seek",
                            subtitle: "Tap sides to skip",
                            icon: "hand.tap.fill",
                            isOn: $playerSettings.doubleTapSeekEnabled
                        )
                        
                        SettingsToggleRow(
                            title: "Hold for 2x Speed",
                            subtitle: "Long press for fast forward",
                            icon: "hare.fill",
                            isOn: $playerSettings.holdFor2xSpeedEnabled
                        )
                    }
                    
                    // Subtitles Section
                    SettingsSection(title: "Subtitles", icon: "captions.bubble.fill") {
                        SettingsRow(title: "Font Size", icon: "textformat.size") {
                            Picker("", selection: Binding(
                                get: { playerSettings.subtitleSize },
                                set: { playerSettings.subtitleSize = $0 }
                            )) {
                                ForEach(SubtitleSize.allCases, id: \.self) { size in
                                    Text(size.displayName).tag(size)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.white)
                        }
                        
                        SettingsSliderRow(
                            title: "Background Opacity",
                            icon: "rectangle.fill",
                            value: $playerSettings.subtitleBackgroundOpacity,
                            range: 0...1,
                            step: 0.1,
                            unit: "",
                            formatAsPercent: true
                        )
                        
                        SettingsSliderRow(
                            title: "Bottom Margin",
                            icon: "arrow.down.to.line",
                            value: $playerSettings.subtitleBottomMargin,
                            range: 10...100,
                            step: 10,
                            unit: "pt"
                        )
                    }
                    
                    // Video Section
                    SettingsSection(title: "Video", icon: "film.fill") {
                        SettingsToggleRow(
                            title: "Hardware Acceleration",
                            subtitle: "Use GPU for decoding",
                            icon: "cpu.fill",
                            isOn: $playerSettings.hardwareAccelerationEnabled
                        )
                        
                        SettingsRow(title: "Decoder", icon: "waveform") {
                            Picker("", selection: Binding(
                                get: { playerSettings.decoderPreference },
                                set: { playerSettings.decoderPreference = $0 }
                            )) {
                                ForEach(DecoderPreference.allCases, id: \.self) { pref in
                                    Text(pref.displayName).tag(pref)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.white)
                        }
                        
                        SettingsRow(title: "Buffer Size", icon: "arrow.down.circle.fill") {
                            Picker("", selection: Binding(
                                get: { playerSettings.bufferSize },
                                set: { playerSettings.bufferSize = $0 }
                            )) {
                                ForEach(BufferSize.allCases, id: \.self) { size in
                                    Text(size.displayName).tag(size)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.white)
                        }
                        
                        SettingsToggleRow(
                            title: "Picture-in-Picture",
                            subtitle: "Enable PiP mode",
                            icon: "pip.fill",
                            isOn: $playerSettings.pipEnabled
                        )
                        
                        SettingsToggleRow(
                            title: "Background Playback",
                            subtitle: "Continue audio in background",
                            icon: "speaker.wave.2.fill",
                            isOn: $playerSettings.backgroundPlaybackEnabled
                        )
                        
                        SettingsToggleRow(
                            title: "Auto-Rotate",
                            subtitle: "Follow device orientation",
                            icon: "rotate.right.fill",
                            isOn: $playerSettings.autoRotateEnabled
                        )
                        
                        SettingsToggleRow(
                            title: "Skip Silence",
                            subtitle: "Skip silent audio sections",
                            icon: "waveform.path",
                            isOn: $playerSettings.skipSilenceEnabled
                        )
                    }
                    
                    // About Section
                    SettingsSection(title: "About", icon: "info.circle.fill") {
                        SettingsInfoRow(
                            title: "Version",
                            icon: "number",
                            value: appSettings.appVersion
                        )
                        
                        SettingsInfoRow(
                            title: "Build",
                            icon: "hammer.fill",
                            value: appSettings.buildNumber
                        )
                        
                        SettingsButtonRow(
                            title: "Reset All Settings",
                            icon: "arrow.counterclockwise",
                            isDestructive: true
                        ) {
                            showResetConfirmation = true
                        }
                    }
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text("PrismPlay")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                        Text("Made with ❤️")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .padding(.bottom, 50)
            }
        }
        .alert("Reset Settings", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                playerSettings.resetToDefaults()
            }
        } message: {
            Text("This will reset all player settings to their default values. This action cannot be undone.")
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.purple)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            
            // Section Content
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Settings Row Types

struct SettingsRow<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 28)
            
            Text(title)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.purple)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsSliderRow: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var formatAsPercent: Bool = false
    
    var displayValue: String {
        if formatAsPercent {
            return "\(Int(value * 100))%"
        } else {
            return "\(Int(value))\(unit)"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 28)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(displayValue)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.purple)
                    .frame(minWidth: 50, alignment: .trailing)
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(.purple)
                .padding(.leading, 36)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsInfoRow: View {
    let title: String
    let icon: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 28)
            
            Text(title)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsButtonRow: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isDestructive ? .red : .white.opacity(0.7))
                    .frame(width: 28)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(isDestructive ? .red : .white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

#Preview {
    SettingsView()
}
