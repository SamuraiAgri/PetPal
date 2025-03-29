import SwiftUI

struct PetGuideView: View {
    @State private var selectedCategory = "犬"
    private let categories = ["犬", "猫", "小動物", "緊急時"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // カテゴリ選択
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedCategory == category ? Color.primaryApp : Color.backgroundSecondary)
                                    )
                                    .foregroundColor(selectedCategory == category ? .white : .textPrimary)
                                    .fontWeight(selectedCategory == category ? .semibold : .regular)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color.backgroundSecondary.opacity(0.5))
                
                // ガイドコンテンツ
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedCategory {
                        case "犬":
                            dogGuideContent
                        case "猫":
                            catGuideContent
                        case "小動物":
                            smallAnimalGuideContent
                        case "緊急時":
                            emergencyGuideContent
                        default:
                            Text("コンテンツが準備中です")
                                .padding()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("飼育ガイド")
        }
    }
    // 犬のガイドコンテンツ
        private var dogGuideContent: some View {
            VStack(alignment: .leading, spacing: 24) {
                guideSection(
                    title: "日常のケア",
                    items: [
                        GuideItem(
                            title: "散歩",
                            description: "1日1〜2回の散歩が理想的です。犬種や年齢によって必要な運動量は異なります。子犬や高齢犬は短い散歩を複数回に分けるとよいでしょう。",
                            icon: "figure.walk"
                        ),
                        GuideItem(
                            title: "ブラッシング",
                            description: "短毛種は週1〜2回、長毛種は毎日ブラッシングが必要です。抜け毛の多い季節は頻度を増やしましょう。",
                            icon: "scissors"
                        ),
                        GuideItem(
                            title: "歯のケア",
                            description: "歯周病予防のため、犬用歯ブラシと歯磨き粉で週に数回磨いてあげましょう。デンタルガムやおもちゃも効果的です。",
                            icon: "mouth.fill"
                        )
                    ]
                )
                
                guideSection(
                    title: "食事管理",
                    items: [
                        GuideItem(
                            title: "食事回数",
                            description: "成犬の場合、朝と夕方の1日2回が一般的です。子犬は1日3〜4回に分けて与えましょう。",
                            icon: "clock.fill"
                        ),
                        GuideItem(
                            title: "適切な量",
                            description: "年齢、体重、活動量に合わせて調整します。フード袋の給餌ガイドを参考にしつつ、体型を見ながら調整が必要です。",
                            icon: "scalemass.fill"
                        ),
                        GuideItem(
                            title: "与えてはいけない食べ物",
                            description: "チョコレート、ぶどう、レーズン、玉ねぎ、ニンニク、キシリトール含有食品、アルコール、カフェインなどは犬に有毒です。",
                            icon: "exclamationmark.triangle.fill"
                        )
                    ]
                )
                
                guideSection(
                    title: "健康管理",
                    items: [
                        GuideItem(
                            title: "予防接種",
                            description: "混合ワクチンや狂犬病ワクチンを定期的に接種しましょう。子犬期は数回の接種が必要です。",
                            icon: "syringe.fill"
                        ),
                        GuideItem(
                            title: "寄生虫対策",
                            description: "ノミ・ダニ・フィラリア予防を定期的に行いましょう。季節や居住地域によって必要な対策は異なります。",
                            icon: "ladybug.fill"
                        ),
                        GuideItem(
                            title: "定期健康診断",
                            description: "若い健康な犬は年1回、7歳以上のシニア犬は半年に1回の健康診断がおすすめです。",
                            icon: "stethoscope"
                        )
                    ]
                )
            }
        }
        
        // 猫のガイドコンテンツ
        private var catGuideContent: some View {
            VStack(alignment: .leading, spacing: 24) {
                guideSection(
                    title: "日常のケア",
                    items: [
                        GuideItem(
                            title: "グルーミング",
                            description: "短毛種は週1回、長毛種は毎日ブラッシングしましょう。抜け毛や毛玉防止に効果的です。多くの猫は自分で毛づくろいしますが、年齢や健康状態によってはサポートが必要です。",
                            icon: "scissors"
                        ),
                        GuideItem(
                            title: "爪とぎ",
                            description: "健康な爪の維持のため、爪とぎポストを用意しましょう。家具を守るためにも重要です。",
                            icon: "pawprint.fill"
                        ),
                        GuideItem(
                            title: "トイレ管理",
                            description: "猫用トイレは清潔に保ち、毎日掃除しましょう。理想的には猫の数+1個のトイレを用意するとよいでしょう。",
                            icon: "trash.fill"
                        )
                    ]
                )
                
                guideSection(
                    title: "食事管理",
                    items: [
                        GuideItem(
                            title: "食事タイプ",
                            description: "ドライフードとウェットフードを組み合わせるのが理想的です。年齢、健康状態、活動量に合わせたフードを選びましょう。",
                            icon: "fork.knife"
                        ),
                        GuideItem(
                            title: "給水",
                            description: "常に新鮮な水を用意しましょう。多くの猫は流れる水を好むため、ウォーターファウンテンも効果的です。",
                            icon: "drop.fill"
                        ),
                        GuideItem(
                            title: "与えてはいけない食べ物",
                            description: "チョコレート、カフェイン、アルコール、玉ねぎ、ニンニク、生の卵、生の魚、乳製品などは猫に有害です。",
                            icon: "exclamationmark.triangle.fill"
                        )
                    ]
                )
                
                guideSection(
                    title: "健康管理",
                    items: [
                        GuideItem(
                            title: "予防接種",
                            description: "3種・4種混合ワクチンを定期的に接種しましょう。室内飼いでも感染症予防は重要です。",
                            icon: "syringe.fill"
                        ),
                        GuideItem(
                            title: "寄生虫対策",
                            description: "定期的なノミ・ダニ駆除を行いましょう。室内飼いでも感染リスクはあります。",
                            icon: "ladybug.fill"
                        ),
                        GuideItem(
                            title: "定期健康診断",
                            description: "若い健康な猫は年1回、7歳以上のシニア猫は半年に1回の健康診断がおすすめです。",
                            icon: "stethoscope"
                        )
                    ]
                )
            }
        }
        
        // 小動物のガイドコンテンツ
        private var smallAnimalGuideContent: some View {
            VStack(alignment: .leading, spacing: 24) {
                guideSection(
                    title: "ハムスター",
                    items: [
                        GuideItem(
                            title: "住環境",
                            description: "床面積が広いケージを選び、床材（無香料・無着色のもの）、隠れ家、給水ボトル、回し車、かじり木を用意しましょう。",
                            icon: "house.fill"
                        ),
                        GuideItem(
                            title: "食事",
                            description: "ハムスター専用のペレット食を基本に、少量の野菜や果物を与えます。脂質の多いひまわりの種などは与えすぎに注意しましょう。",
                            icon: "leaf.fill"
                        ),
                        GuideItem(
                            title: "世話のポイント",
                            description: "週に1回程度ケージの掃除をし、新鮮な水を毎日与えましょう。夜行性なので、昼間は静かに休ませてあげましょう。",
                            icon: "moon.stars.fill"
                        )
                    ]
                )
                
                guideSection(
                    title: "ウサギ",
                    items: [
                        GuideItem(
                            title: "住環境",
                            description: "十分な広さのケージと、毎日自由に動ける時間・空間を確保しましょう。トイレ、隠れ家、牧草入れ、給水器が必要です。",
                            icon: "house.fill"
                        ),
                        GuideItem(
                            title: "食事",
                            description: "食事の80%は良質な牧草（チモシー）で、残りはウサギ用ペレットと少量の野菜です。果物や穀物は少量に留めましょう。",
                            icon: "leaf.fill"
                        ),
                        GuideItem(
                            title: "健康管理",
                            description: "定期的な爪切り、歯のチェック、毛づくろいのサポートが必要です。ウサギ専門の獣医での健康診断も重要です。",
                            icon: "stethoscope"
                        )
                    ]
                )
                
                guideSection(
                    title: "フェレット",
                    items: [
                        GuideItem(
                            title: "住環境",
                            description: "多層式の大きなケージと、毎日数時間の運動時間が必要です。寝床、トイレ、給水器、遊び道具を用意しましょう。",
                            icon: "house.fill"
                        ),
                        GuideItem(
                            title: "食事",
                            description: "高タンパク・低炭水化物のフェレット専用フードを基本に、時々生肉や適切なおやつを与えます。猫用フードも代用可能です。",
                            icon: "fork.knife"
                        ),
                        GuideItem(
                            title: "社会化と健康管理",
                            description: "人との触れ合いを十分に確保し、定期的なワクチン接種と年1回の健康診断が必要です。歯石のチェックも重要です。",
                            icon: "heart.fill"
                        )
                    ]
                )
            }
        }
        
        // 緊急時のガイドコンテンツ
        private var emergencyGuideContent: some View {
            VStack(alignment: .leading, spacing: 24) {
                Text("緊急時の対応")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("以下の症状が見られる場合は、すぐに動物病院を受診してください。")
                    .font(.body)
                    .padding(.bottom)
                
                emergencyItem(
                    symptom: "呼吸困難",
                    description: "口を開けて呼吸する、呼吸が浅く速い、ゼーゼー・ヒューヒュー音がする",
                    severity: "最重度"
                )
                
                emergencyItem(
                    symptom: "出血",
                    description: "止まらない出血、大量の出血がある場合",
                    severity: "重度"
                )
                
                emergencyItem(
                    symptom: "嘔吐・下痢",
                    description: "繰り返す嘔吐、血液の混じった嘔吐や下痢、24時間以上続く場合",
                    severity: "中〜重度"
                )
                
                emergencyItem(
                    symptom: "食欲不振",
                    description: "24時間以上何も食べない場合（特に小型犬や猫は危険）",
                    severity: "中度"
                )
                
                emergencyItem(
                    symptom: "突然の歩行困難",
                    description: "後ろ足を引きずる、ふらつく、バランスを崩す",
                    severity: "重度"
                )
                
                emergencyItem(
                    symptom: "痙攣・発作",
                    description: "身体が硬直する、意識がない、体が震える",
                    severity: "最重度"
                )
                
                emergencyItem(
                    symptom: "腹部の膨張・硬さ",
                    description: "お腹が膨らんで硬い、触ると痛がる",
                    severity: "重度"
                )
                
                emergencyItem(
                    symptom: "誤飲",
                    description: "中毒性のあるもの（チョコレート、医薬品など）を食べた場合",
                    severity: "重度"
                )
            }
        }
        
        // ガイドセクションのビュー
        private func guideSection(title: String, items: [GuideItem]) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                ForEach(items) { item in
                    guideItemView(item: item)
                }
            }
        }
        
        // ガイドアイテムのビュー
        private func guideItemView(item: GuideItem) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: item.icon)
                        .font(.title3)
                        .foregroundColor(.primaryApp)
                        .frame(width: 30)
                    
                    Text(item.title)
                        .font(.headline)
                }
                
                Text(item.description)
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .padding(.leading, 36)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .fill(Color.backgroundPrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        
        // 緊急アイテムのビュー
        private func emergencyItem(symptom: String, description: String, severity: String) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(severityColor(severity))
                        .frame(width: 12, height: 12)
                    
                    Text(symptom)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(severity)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(severityColor(severity).opacity(0.2))
                        )
                        .foregroundColor(severityColor(severity))
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .padding(.leading, 24)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .fill(Color.backgroundPrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .stroke(severityColor(severity).opacity(0.3), lineWidth: 1)
            )
        }
        
        // 緊急度に応じた色を返す
        private func severityColor(_ severity: String) -> Color {
            switch severity {
            case "最重度":
                return .red
            case "重度":
                return .orange
            case "中度":
                return .yellow
            default:
                return .blue
            }
        }
    }

    // ガイドアイテムモデル
    struct GuideItem: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let icon: String
    }
