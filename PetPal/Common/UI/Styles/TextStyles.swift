import SwiftUI

struct TitleText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.textPrimary)
    }
}

struct SubtitleText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.textPrimary)
    }
}

struct BodyText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundColor(.textPrimary)
    }
}

struct CaptionText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(.textSecondary)
    }
}

extension Text {
    func titleStyle() -> some View {
        self.modifier(TitleText())
    }
    
    func subtitleStyle() -> some View {
        self.modifier(SubtitleText())
    }
    
    func bodyStyle() -> some View {
        self.modifier(BodyText())
    }
    
    func captionStyle() -> some View {
        self.modifier(CaptionText())
    }
}
