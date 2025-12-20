import SwiftUI

// MARK: - Lifegames Pro - Default Files View
// For unregistered users - shows sample content with registration prompt

struct LifegamesDefaultFilesView: View {
    var sampleFile: LifegamesSampleFile = .default
    var onRegisterTapped: (() -> Void)?
    var onFileTapped: ((LifegamesSampleFile) -> Void)?

    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var isDownloaded = false
    @State private var showBenefits = false

    private let theme = DarkProfessionalTheme()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    iconHeader
                    sampleSection.padding(.top, 20)
                    Spacer(minLength: 60)
                    bottomCTA
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                }
            }
            .background(theme.backgroundColor)
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Icon Header

    private var iconHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(theme.primaryColor)
            Text("Try the sample file below to see how downloading works.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.primaryColor.opacity(0.1))
    }

    // MARK: - Sample Section

    private var sampleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SAMPLE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 20)
            sampleFileRow.padding(.horizontal, 16)
        }
    }

    private var sampleFileRow: some View {
        Button(action: { isDownloaded ? onFileTapped?(sampleFile) : startDownload() }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [theme.primaryColor, theme.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)

                    if isDownloading {
                        CircularProgressView(progress: downloadProgress, theme: theme)
                    } else if isDownloaded {
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(sampleFile.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)

                    Text(isDownloaded ? "Ready to play" : sampleFile.formattedSize)
                        .font(.caption)
                        .foregroundStyle(isDownloaded ? theme.successColor : theme.textSecondary)
                }

                Spacer()
            }
            .padding(12)
            .background(DarkProfessionalTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 16) {
            Text("Want your own videos?")
                .font(.subheadline)
                .foregroundStyle(.white)

            Button(action: { onRegisterTapped?() }) {
                Text("Create Free Account")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }

            Button(action: { withAnimation(.spring(response: 0.3)) { showBenefits.toggle() } }) {
                HStack(spacing: 4) {
                    Text("Why create an account?")
                    Image(systemName: showBenefits ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            }

            if showBenefits {
                VStack(alignment: .leading, spacing: 8) {
                    benefitRow(icon: "icloud.and.arrow.down", text: "Download videos from your personal library")
                    benefitRow(icon: "arrow.triangle.2.circlepath", text: "Sync across all your devices")
                    benefitRow(icon: "bell.badge", text: "Get notified when new content is available")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(DarkProfessionalTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.primaryColor.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(theme.primaryColor)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Download

    private func startDownload() {
        isDownloading = true
        downloadProgress = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if downloadProgress >= 1.0 {
                timer.invalidate()
                isDownloading = false
                isDownloaded = true
            } else {
                downloadProgress += 0.02
            }
        }
    }
}

// MARK: - Shared Components

private struct CircularProgressView: View {
    let progress: Double
    let theme: DarkProfessionalTheme
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Sample File Model

struct LifegamesSampleFile: Identifiable {
    let id: String
    let title: String
    let description: String
    let duration: String
    let size: Int

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    static let `default` = LifegamesSampleFile(
        id: "sample-1",
        title: "Welcome to Lifegames",
        description: "A quick introduction to the app and its features.",
        duration: "2:30",
        size: 45_000_000
    )
}

// MARK: - Preview

#Preview("Default Files") {
    LifegamesDefaultFilesView()
}
