import SwiftUI

// MARK: - User Profile Data

struct UserProfile {
    let name: String
    let email: String
    let avatarURL: URL?

    static let placeholder = UserProfile(
        name: "John Appleseed",
        email: "john@example.com",
        avatarURL: nil
    )
}

// MARK: - Profile Header Component

struct ProfileHeader: View {
    let profile: UserProfile
    var showEditButton: Bool = true
    var onEditTapped: (() -> Void)?

    private let theme = DarkProfessionalTheme()

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                avatarView(size: 80, borderColor: theme.primaryColor, borderWidth: 3)

                if showEditButton {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(theme.primaryColor)
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(profile.email)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()
        }
        .padding(20)
        .background(DarkProfessionalTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Avatar View

    private func avatarView(size: CGFloat, borderColor: Color, borderWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Initials
            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Circle()
                .stroke(borderColor, lineWidth: borderWidth)
                .frame(width: size, height: size)
        }
    }

    private var initials: String {
        let names = profile.name.split(separator: " ")
        let firstInitial = names.first?.prefix(1) ?? ""
        let lastInitial = names.count > 1 ? names.last?.prefix(1) ?? "" : ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
}

// MARK: - Preview

#Preview("Profile Header") {
    let theme = DarkProfessionalTheme()

    VStack(spacing: 24) {
        ProfileHeader(profile: .placeholder)
        ProfileHeader(profile: .placeholder, showEditButton: false)
    }
    .padding()
    .background(theme.backgroundColor)
    .preferredColorScheme(.dark)
}
