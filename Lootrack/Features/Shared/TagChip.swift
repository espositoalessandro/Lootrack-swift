import SwiftUI

struct TagFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(
        horizontalSpacing: CGFloat = 8,
        verticalSpacing: CGFloat = 8
    ) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth =
            proposal.width ?? .infinity

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size =
                subview.sizeThatFits(
                    .unspecified
                )

            if currentX > 0,
                currentX + size.width > maxWidth
            {
                currentX = 0
                currentY +=
                    rowHeight
                    + verticalSpacing

                rowHeight = 0
            }

            currentX +=
                size.width
                + horizontalSpacing

            rowHeight = max(
                rowHeight,
                size.height
            )
        }

        return CGSize(
            width:
                proposal.width
                ?? currentX,
            height:
                currentY
                + rowHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX =
            bounds.minX

        var currentY =
            bounds.minY

        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size =
                subview.sizeThatFits(
                    .unspecified
                )

            if currentX > bounds.minX,
                currentX + size.width
                    > bounds.maxX
            {
                currentX =
                    bounds.minX

                currentY +=
                    rowHeight
                    + verticalSpacing

                rowHeight = 0
            }

            subview.place(
                at: CGPoint(
                    x: currentX,
                    y: currentY
                ),
                proposal:
                    ProposedViewSize(
                        size
                    )
            )

            currentX +=
                size.width
                + horizontalSpacing

            rowHeight = max(
                rowHeight,
                size.height
            )
        }
    }
}

struct TagChip: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.subheadline)
            .padding(
                .horizontal,
                10
            )
            .padding(
                .vertical,
                5
            )
            .background(
                .quaternary,
                in: Capsule()
            )
    }
}
