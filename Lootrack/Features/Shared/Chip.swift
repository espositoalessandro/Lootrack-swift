import SwiftUI

struct Chip: View {
    let text: String
    
    let leadingSystemImage: String?
    let trailingSystemImage: String?
    
    let action: (() -> Void)?
    
    init(
        _ text: String,
        leadingSystemImage: String? = nil,
        trailingSystemImage: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.text = text
        self.leadingSystemImage = leadingSystemImage
        self.trailingSystemImage = trailingSystemImage
        self.action = action
    }
    
    var body: some View {
        if let action {
            Button(
                action: action
            ) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
    
    private var content: some View {
        HStack(spacing: 5) {
            if let leadingSystemImage {
                Image(
                    systemName: leadingSystemImage
                )
                .foregroundStyle(.secondary)
            }
            
            Text(text)
                .lineLimit(1)
            
            if let trailingSystemImage {
                Image(
                    systemName: trailingSystemImage
                )
                .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            5
        )
        .foregroundStyle(.primary)
        .background(
            .quaternary,
            in: Capsule()
        )
        .contentShape(
            Capsule()
        )
    }
}
