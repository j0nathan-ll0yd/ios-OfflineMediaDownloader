import ComposableArchitecture
import DesignSystem
import LifegamesComponents
import LifegamesTokens
import PreviewFixtures
import SharedModels
import SwiftUI

public struct EditProfileView: View {
  @Bindable var store: StoreOf<EditProfileFeature>

  public init(store: StoreOf<EditProfileFeature>) {
    self.store = store
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: Spacing.s500) {
        field(title: "First Name", text: $store.firstName, placeholder: "First name")
        field(title: "Last Name", text: $store.lastName, placeholder: "Last name")
        readOnlyField(title: "Email", value: store.email.isEmpty ? "No email" : store.email)

        LGButton(store.isSaving ? "Saving…" : "Save Changes", variant: .primary) {
          store.send(.saveButtonTapped)
        }
        .disabled(!store.canSave || store.isSaving)
        .opacity(!store.canSave || store.isSaving ? 0.5 : 1.0)
      }
      .padding(Spacing.s400)
    }
    .background(LGColor.surfaceBase.ignoresSafeArea())
    .navigationTitle("Edit Profile")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarColorScheme(.dark, for: .navigationBar)
    #endif
      .preferredColorScheme(.dark)
      .task { store.send(.onAppear) }
  }

  private func field(title: String, text: Binding<String>, placeholder: String) -> some View {
    VStack(alignment: .leading, spacing: Spacing.s200) {
      Text(title)
        .font(OMDFont.semibold(11))
        .foregroundStyle(LGColor.accentBlue)
        .textCase(.uppercase)
        .tracking(1.5)

      TextField(placeholder, text: text)
        .font(OMDFont.regular(16))
        .foregroundStyle(LGColor.textTitle)
        .textFieldStyle(.plain)
      #if os(iOS)
        .textInputAutocapitalization(.words)
      #endif
        .autocorrectionDisabled()
        .padding(Spacing.s400)
        .background(LGColor.surfaceRaised)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(LGColor.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private func readOnlyField(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: Spacing.s200) {
      Text(title)
        .font(OMDFont.semibold(11))
        .foregroundStyle(LGColor.textMuted)
        .textCase(.uppercase)
        .tracking(1.5)

      Text(value)
        .font(OMDFont.regular(16))
        .foregroundStyle(LGColor.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s400)
        .background(LGColor.surfaceRaised.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }
}

#Preview {
  NavigationStack {
    EditProfileView(
      store: Store(
        initialState: EditProfileFeature.State(
          user: PreviewFixtures.user(.standard)
        )
      ) {
        EditProfileFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
