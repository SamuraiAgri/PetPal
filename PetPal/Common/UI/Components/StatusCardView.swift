import SwiftUI

struct StatusCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .fill(Color.backgroundPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct StatusCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            StatusCardView(
                title: "体重",
                value: "5.2 kg",
                icon: "scalemass.fill",
                color: .accentApp
            )
            
            StatusCardView(
                title: "最終散歩",
                value: "今日 15:30",
                icon: "figure.walk",
                color: .walkApp
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
