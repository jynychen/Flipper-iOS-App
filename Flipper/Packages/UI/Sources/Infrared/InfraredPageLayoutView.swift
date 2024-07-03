import SwiftUI
import Core

struct InfraredPageLayoutView: View {
    let page: InfraredPageLayout = .mock

    var body: some View {
        GeometryReader { viewGeometry in
            ZStack {
                GeometryReader { layoutGeometry in
                    ForEach(page.buttons) { button in
                        InfraredButtonView(
                            button: button,
                            cellLenght: calculateCellLenght(layoutGeometry.size)
                        )
                        .cellModifier(
                            button: button,
                            layoutSize: layoutGeometry.size
                        )
                    }
                }
            }
            .layoutModifier(viewGeometry.size)
        }
    }
}

private extension View {
    var layoutDefaultWidth: Double { 375.0 }
    var layoutDefaultHeight: Double { 692.0 }

    @ViewBuilder
    func layoutModifier(_ viewSize: CGSize) -> some View {
        let widthScaleFactor = viewSize.width / layoutDefaultWidth
        let heightScaleFactor = viewSize.height / layoutDefaultHeight

        let scaleFactor = min(widthScaleFactor, heightScaleFactor)

        let viewWidth = layoutDefaultWidth * scaleFactor
        let viewHeight = layoutDefaultHeight * scaleFactor

        self
            .frame(
                width: viewWidth,
                height: viewHeight)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .center)
            .environment(\.layoutScaleFactor, scaleFactor)
    }

    var widthCellCount: Double { 5 }
    var heightCellCount: Double { 11 }

    @ViewBuilder
    func cellModifier(
        button: InfraredButton,
        layoutSize: CGSize
    ) -> some View {
        let xCenter = button.x + button.containerWidth / 2
        let yCenter = button.y + button.containerHeight / 2

        let widthFactor = layoutSize.width / widthCellCount
        let heightFactor = layoutSize.height / heightCellCount

        let cellWidth = widthFactor * button.containerWidth
        let cellHeight = heightFactor * button.containerHeight

        let cellX = layoutSize.width * xCenter / widthCellCount
        let cellY = layoutSize.height * yCenter / heightCellCount
        let cellAlignment = button.cellAlignment

        self
            .frame(
                width: cellWidth,
                height: cellHeight,
                alignment: cellAlignment
            )
            .position(x: cellX, y: cellY)
            .zIndex(button.zIndex)
    }

    var cellHeightCoefficient: Double { 12 }
    var cellWidthCoefficient: Double { 6 }

    func calculateCellLenght(_ screenSize: CGSize) -> Double {
        let cellWidth = screenSize.width / cellWidthCoefficient
        let cellHeight = screenSize.height / cellHeightCoefficient

        return min(cellWidth, cellHeight)
    }
}

extension InfraredButton {
    public var cellAlignment: SwiftUI.Alignment {
        switch self.alignment {
        case .center: .center
        case .topLeft: .topLeading
        case .topRight: .topTrailing
        case .bottomLeft: .bottomLeading
        case .bottomRight: .bottomTrailing
        case .centerLeft: .leading
        case .centerRight: .trailing
        }
    }
}

extension EnvironmentValues {
    @Entry var layoutScaleFactor: Double = 1.0
}

#Preview {
    InfraredPageLayoutView()
}
