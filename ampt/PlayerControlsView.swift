//
//  PlayerControlsView.swift
//  ampt
//

import SwiftUI

struct PlayerControlsView: View {
    @Bindable var state: PlayerState
    @State private var showingVolume = false

    var body: some View {
        VStack(spacing: 8) {
            // Current track info
            Text(state.currentTrack?.displayName ?? "No track")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)

            // Progress bar
            ProgressView(state: state)

            // Transport controls with volume button overlay
            ZStack {
                // Transport controls (always centered)
                transportControls
                    .opacity(showingVolume ? 0 : 1)

                // Volume slider (slides in from right)
                volumeSlider
                    .opacity(showingVolume ? 1 : 0)

                // Volume/close button (right aligned, fixed-width container)
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.08)) {
                            showingVolume.toggle()
                        }
                    } label: {
                        Image(systemName: showingVolume ? "xmark" : volumeIcon)
                            .frame(width: 20, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .font(.title3)
                }
            }
        }
        .padding()
    }

    private var volumeIcon: String {
        let volume = state.audioPlayer.volume
        if volume == 0 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private var transportControls: some View {
        HStack(spacing: 16) {
            Button(action: state.previous) {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(.borderless)

            Button(action: state.stop) {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.borderless)

            Button(action: state.togglePlayPause) {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
            .font(.title2)

            Button(action: state.next) {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.borderless)
        }
        .font(.title3)
    }

    private var volumeSlider: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { Double(state.audioPlayer.volume) },
                set: { state.audioPlayer.volume = Float($0) }
            ), in: 0...1)
            .frame(width: 100)
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ProgressView: View {
    @Bindable var state: PlayerState

    var body: some View {
        VStack(spacing: 2) {
            // Clickable progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Progress fill
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: progressWidth(in: geometry.size.width), height: 6)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            seek(to: value.location.x, in: geometry.size.width)
                        }
                )
            }
            .frame(height: 6)

            // Time labels
            HStack {
                Text(formatTime(state.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text(formatTime(state.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard state.duration > 0 else { return 0 }
        let progress = state.currentTime / state.duration
        return totalWidth * CGFloat(progress)
    }

    private func seek(to x: CGFloat, in totalWidth: CGFloat) {
        guard state.duration > 0 else { return }
        let progress = max(0, min(1, x / totalWidth))
        let targetTime = state.duration * Double(progress)
        state.seek(to: targetTime)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
