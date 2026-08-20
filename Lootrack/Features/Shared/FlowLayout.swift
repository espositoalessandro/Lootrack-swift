import SwiftUI

struct FlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat = 8,
         verticalSpacing: CGFloat = 8)
    {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache _: inout ()) -> CGSize
    {
        let maxWidth =
            proposal.width ?? .infinity

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for subview in subviews {
            let size =
                subview.sizeThatFits(.unspecified)

            if currentX > 0,
               currentX + size.width > maxWidth
            {
                contentWidth = max(contentWidth,
                                   currentX - horizontalSpacing)

                currentX = 0

                currentY +=
                    rowHeight
                    + verticalSpacing

                rowHeight = 0
            }

            currentX +=
                size.width
                + horizontalSpacing

            rowHeight = max(rowHeight,
                            size.height)
        }

        contentWidth = max(contentWidth,
                           max(0,
                               currentX - horizontalSpacing))

        return CGSize(width:
            proposal.width
                ?? contentWidth,
            height:
            currentY
                + rowHeight)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal _: ProposedViewSize,
                       subviews: Subviews,
                       cache _: inout ())
    {
        var currentX =
            bounds.minX

        var currentY =
            bounds.minY

        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size =
                subview.sizeThatFits(.unspecified)

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

            subview.place(at: CGPoint(x: currentX,
                                      y: currentY),
                          proposal:
                          ProposedViewSize(size))

            currentX +=
                size.width
                + horizontalSpacing

            rowHeight = max(rowHeight,
                            size.height)
        }
    }
}
