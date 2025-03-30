// PetPal/Common/UI/Components/PetAvatarView.swift
import SwiftUI

struct PetAvatarView: View {
    let imageData: Data?
    let size: CGFloat
    
    var body: some View {
        if let imageData = imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 0)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        } else {
            // デフォルト画像をより魅力的に
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.secondaryApp.opacity(0.7), Color.secondaryApp.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Image(systemName: "pawprint.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 0)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}
