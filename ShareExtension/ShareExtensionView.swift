import SwiftUI

struct ShareExtensionView: View {
    enum Status {
        case loading
        case success
        case error(String)
    }

    let status: Status
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch status {
            case .loading:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Sending to Feedly...")
                    .font(.headline)

            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Sent to Feedly")
                    .font(.headline)

            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview("Loading") {
    ShareExtensionView(status: .loading) {}
}

#Preview("Success") {
    ShareExtensionView(status: .success) {}
}

#Preview("Error") {
    ShareExtensionView(status: .error("Only YouTube URLs are supported")) {}
}
