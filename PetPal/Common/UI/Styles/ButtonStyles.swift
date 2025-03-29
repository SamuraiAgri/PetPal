import SwiftUI

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.primaryApp.opacity(configuration.isPressed ? 0.8 : 1))
            .foregroundColor(.white)
            .cornerRadius(Constants.Layout.cornerRadius)
            .shadow(color: Color.primaryApp.opacity(0.3), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Constants.Animation.quick, value: configuration.isPressed)
    }
}

struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.secondaryApp.opacity(configuration.isPressed ? 0.2 : 0.1))
            .foregroundColor(Color.secondaryApp)
            .cornerRadius(Constants.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .stroke(Color.secondaryApp, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Constants.Animation.quick, value: configuration.isPressed)
    }
}

struct DangerButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.errorApp.opacity(configuration.isPressed ? 0.8 : 1))
            .foregroundColor(.white)
            .cornerRadius(Constants.Layout.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Constants.Animation.quick, value: configuration.isPressed)
    }
}

extension View {
    func primaryButton() -> some View {
        self.buttonStyle(PrimaryButton())
    }
    
    func secondaryButton() -> some View {
        self.buttonStyle(SecondaryButton())
    }
    
    func dangerButton() -> some View {
        self.buttonStyle(DangerButton())
    }
}

struct ButtonStyles_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Button("プライマリボタン") {}
                .primaryButton()
            
            Button("セカンダリボタン") {}
                .secondaryButton()
            
            Button("削除ボタン") {}
                .dangerButton()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
