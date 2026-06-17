import ComposableArchitecture
import DesignSystem
import LifegamesComponents
import LifegamesComponentsCore
import LifegamesTokens
import SwiftUI

// MARK: - EmailLoginView

public struct EmailLoginView: View {
  @Bindable var store: StoreOf<EmailLoginFeature>

  public init(store: StoreOf<EmailLoginFeature>) {
    self.store = store
  }

  public var body: some View {
    ZStack {
      LGColor.surfaceBase.ignoresSafeArea()

      VStack(spacing: Spacing.s600) {
        header
        emailField
        LGButton("Continue", variant: .primary) {
          store.send(.continueButtonTapped)
        }
        .disabled(!store.isContinueEnabled)
        .opacity(store.isContinueEnabled ? 1.0 : 0.5)

        Spacer()
      }
      .padding(Spacing.s400)
      .padding(.top, Spacing.s700)
    }
    .preferredColorScheme(.dark)
    .alert($store.scope(state: \.alert, action: \.alert))
  }

  private var header: some View {
    VStack(spacing: Spacing.s300) {
      Text("EMAIL")
        .font(OMDFont.bold(30))
        .tracking(6)
        .foregroundStyle(OMDBrand.wordmarkGradient)
        .shadow(color: LGColor.accentBlue.opacity(0.5), radius: 14)

      Text("Enter your email to continue")
        .font(OMDFont.regular(14))
        .foregroundStyle(LGColor.textMuted)
        .multilineTextAlignment(.center)
    }
  }

  private var emailField: some View {
    VStack(alignment: .leading, spacing: Spacing.s200) {
      Text("Email Address")
        .font(OMDFont.semibold(11))
        .foregroundStyle(LGColor.accentBlue)
        .textCase(.uppercase)
        .tracking(1.5)

      TextField("you@example.com", text: $store.email)
        .font(OMDFont.regular(16))
        .foregroundStyle(LGColor.textTitle)
        .textFieldStyle(.plain)
        .autocorrectionDisabled()
      #if os(iOS)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
      #endif
        .padding(Spacing.s400)
        .background(LGColor.surfaceRaised)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(LGColor.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }
}

#Preview {
  NavigationStack {
    EmailLoginView(
      store: Store(initialState: EmailLoginFeature.State()) {
        EmailLoginFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
