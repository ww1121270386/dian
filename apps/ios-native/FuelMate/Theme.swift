import SwiftUI

enum Theme {
    static let green = Color(red: 0.11, green: 0.67, blue: 0.36)      // #1CAB5C
    static let greenDark = Color(red: 0.06, green: 0.53, blue: 0.28)  // #0F9149
    static let greenLight = Color(red: 0.91, green: 0.97, blue: 0.93)
    static let danger = Color(red: 0.90, green: 0.28, blue: 0.30)
    static let warn = Color(red: 0.85, green: 0.55, blue: 0.10)
    static let card = Color(.secondarySystemGroupedBackground)
    static let bg = Color(.systemGroupedBackground)

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [
            Color(red: 0.28, green: 0.77, blue: 0.45),
            Color(red: 0.11, green: 0.67, blue: 0.36),
            Color(red: 0.06, green: 0.53, blue: 0.28)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct CardBox<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SectionTitle: View {
    let text: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(text).font(.subheadline).fontWeight(.semibold)
            Spacer()
            if let t = trailing, let a = action {
                Button(t, action: a).font(.footnote).foregroundStyle(Theme.green)
            }
        }
    }
}
