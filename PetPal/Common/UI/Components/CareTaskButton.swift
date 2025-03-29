import SwiftUI

struct CareTaskButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.textPrimary)
            }
        }
    }
}

struct CareTaskButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            CareTaskButton(
                title: "散歩",
                icon: "figure.walk",
                color: .walkApp,
                action: {}
            )
            
            CareTaskButton(
                title: "給餌",
                icon: "cup.and.saucer.fill",
                color: .feedingApp,
                action: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
