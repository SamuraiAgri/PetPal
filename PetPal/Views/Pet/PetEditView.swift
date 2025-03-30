// PetPal/Views/Pet/PetEditView.swift
import SwiftUI
import PhotosUI

struct PetEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let isNewPet: Bool
    var initialPet: PetModel?
    let onSave: (PetModel) -> Void
    
    @State private var name: String = ""
    @State private var species: String = Constants.PetSpecies.dog
    @State private var breed: String = ""
    @State private var birthDate: Date = Date()
    @State private var gender: String = "オス"
    @State private var notes: String = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    
    @State private var showingErrors = false
    @State private var errorMessage = ""
    
    init(isNewPet: Bool, initialPet: PetModel? = nil, onSave: @escaping (PetModel) -> Void) {
        self.isNewPet = isNewPet
        self.initialPet = initialPet
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 基本情報
                Section(header: Text("基本情報")) {
                    // ペット画像選択
                    HStack {
                        Spacer()
                        imageSelectionView
                            .onTapGesture {
                                showingImagePicker = true
                            }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                    
                    // 名前
                    TextField("名前", text: $name)
                    
                    // 種類選択
                    Picker("種類", selection: $species) {
                        ForEach(Constants.PetSpecies.all, id: \.self) { species in
                            Text(species).tag(species)
                        }
                    }
                    
                    // 品種
                    TextField("品種（任意）", text: $breed)
                    
                    // 誕生日
                    DatePicker("誕生日", selection: $birthDate, displayedComponents: .date)
                    
                    // 性別
                    Picker("性別", selection: $gender) {
                        Text("オス").tag("オス")
                        Text("メス").tag("メス")
                        Text("不明").tag("不明")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // メモ
                Section(header: Text("メモ")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(isNewPet ? "ペットを追加" : "ペットを編集")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveAction()
                    }
                }
            }
            .onAppear {
                if let pet = initialPet {
                    name = pet.name
                    species = pet.species
                    breed = pet.breed
                    birthDate = pet.birthDate
                    gender = pet.gender
                    notes = pet.notes
                    
                    if let imageData = pet.iconImageData, let image = UIImage(data: imageData) {
                        selectedImage = image
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                PHPickerView(image: $selectedImage)
            }
            .alert("入力エラー", isPresented: $showingErrors) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // 画像選択ビュー
    private var imageSelectionView: some View {
        VStack {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            } else {
                ZStack {
                    Circle()
                        .fill(Color.secondaryApp.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color.secondaryApp)
                }
            }
            
            Text(selectedImage == nil ? "タップして写真を追加" : "タップして写真を変更")
                .font(.caption)
                .foregroundColor(.secondaryApp)
                .padding(.top, 8)
        }
    }
    
    // 保存アクション
    private func saveAction() {
        // 入力バリデーション
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "ペットの名前を入力してください"
            showingErrors = true
            return
        }
        
        var petModel: PetModel
        
        if isNewPet {
            petModel = PetModel(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                species: species,
                breed: breed.trimmingCharacters(in: .whitespacesAndNewlines),
                birthDate: birthDate,
                gender: gender,
                iconImageData: selectedImage?.jpegData(compressionQuality: 0.7),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else if let existingPet = initialPet {
            petModel = existingPet
            petModel.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            petModel.species = species
            petModel.breed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
            petModel.birthDate = birthDate
            petModel.gender = gender
            petModel.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let image = selectedImage {
                petModel.iconImageData = image.jpegData(compressionQuality: 0.7)
            }
        } else {
            return
        }
        
        onSave(petModel)
        dismiss()
    }
}

// PhotosUI Picker
struct PHPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerView
        
        init(_ parent: PHPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        if let image = image as? UIImage {
                            // 画像のリサイズ（容量削減のため）
                            let maxSize: CGFloat = 500
                            let resizedImage = self.resizeImage(image, targetSize: CGSize(width: maxSize, height: maxSize))
                            self.parent.image = resizedImage
                        }
                    }
                }
            }
        }
        
        // 画像のリサイズ処理
        private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
            let size = image.size
            let widthRatio  = targetSize.width  / size.width
            let heightRatio = targetSize.height / size.height
            let ratio = min(widthRatio, heightRatio)
            
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: rect)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return newImage ?? image
        }
    }
}
