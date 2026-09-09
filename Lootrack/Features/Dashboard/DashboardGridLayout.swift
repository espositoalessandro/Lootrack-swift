import SwiftUI

nonisolated struct DashboardGridLayout: Layout {
    let spans: [Int]
    
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat
    
    init(spans: [Int], horizontalSpacing: CGFloat = 12, verticalSpacing: CGFloat = 12) {
        self.spans = spans
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let width = proposal.width else {
            return .zero
        }
        
        let frames = frames(for: subviews, width: width)
        
        return CGSize(
            width: width,
            height: frames.map(\.maxY).max() ?? 0
        )
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(for: subviews, width: bounds.width)
        
        for (index, frame) in frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }
    
    private func frames(for subviews: Subviews, width: CGFloat) -> [CGRect] {
        let columnWidth = (width - horizontalSpacing) / 2
        
        var frames: [CGRect] = []
        var currentY: CGFloat = 0
        var currentColumn = 0
        var currentRowHeight: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let span = index < spans.count ? min(max(spans[index], 1), 2) : 1
            
            if span == 2 {
                if currentColumn != 0 {
                    currentY += currentRowHeight + verticalSpacing
                    currentColumn = 0
                    currentRowHeight = 0
                }
                
                let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
                
                frames.append(
                    CGRect(x: 0, y: currentY, width: width, height: size.height)
                )
                
                currentY += size.height + verticalSpacing
                continue
            }
            
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            let x = CGFloat(currentColumn) * (columnWidth + horizontalSpacing)
            
            frames.append(
                CGRect(x: x, y: currentY, width: columnWidth, height: size.height)
            )
            
            currentRowHeight = max(currentRowHeight, size.height)
            currentColumn += 1
            
            if currentColumn == 2 {
                currentY += currentRowHeight + verticalSpacing
                currentColumn = 0
                currentRowHeight = 0
            }
        }
        
        return frames
    }
}
