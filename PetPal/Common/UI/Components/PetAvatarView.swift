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
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        } else {
            // デフォルト画像
            ZStack {
                Circle()
                    .fill(Color.secondaryApp.opacity(0.2))
                
                Image(systemName: "pawprint.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(Color.secondaryApp)
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}
