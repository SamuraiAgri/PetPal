import SwiftUI

extension View {
    // カードスタイルの背景を適用するモディファイア
    func cardStyle(padding: CGFloat = Constants.Layout.standardPadding) -> some View {
        self
            .padding(padding)
            .background(Color.backgroundPrimary)
            .cornerRadius(Constants.Layout.cornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // プライマリボタンスタイルを適用するモディファイア
    func primaryButtonStyle() -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.primaryApp)
            .foregroundColor(.white)
            .cornerRadius(Constants.Layout.cornerRadius)
            .shadow(color: Color.primaryApp.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // セカンダリボタンスタイルを適用するモディファイア
    func secondaryButtonStyle() -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color.secondaryApp.opacity(0.1))
            .foregroundColor(Color.secondaryApp)
            .cornerRadius(Constants.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .stroke(Color.secondaryApp, lineWidth: 1)
            )
    }
    
    // 標準的なテキストフィールドスタイルを適用するモディファイア
    func standardTextFieldStyle() -> some View {
        self
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(Constants.Layout.smallCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.smallCornerRadius)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
    
    // 条件付きモディファイア
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
