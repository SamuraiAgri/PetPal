import SwiftUI

struct EnhancedPetCardView: View {
    let pet: PetModel
    let isSelected: Bool
    let onShare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                PetAvatarView(imageData: pet.iconImageData, size: 60)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.primaryApp : Color.clear, lineWidth: 3)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(pet.species + (pet.breed.isEmpty ? "" : " / \(pet.breed)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("年齢: \(pet.age)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    if pet.isShared {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.infoApp)
                            .font(.headline)
                    }
                    
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primaryApp)
                            .font(.headline)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                .fill(Color.backgroundPrimary)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }
}
