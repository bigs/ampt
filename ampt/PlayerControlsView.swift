//
//  PlayerControlsView.swift
//  ampt
//

import SwiftUI

struct PlayerControlsView: View {
    @Bindable var state: PlayerState

    var body: some View {
        VStack(spacing: 8) {
            // Current track info
            Text(state.currentTrack?.title ?? "No track")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)

            // Progress bar
            ProgressView(state: state)

            // Transport controls
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
        .padding()
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
