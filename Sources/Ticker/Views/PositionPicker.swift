import SwiftUI

/// A miniature screen with nine drop zones. The selected zone shows a little glass tile.
struct PositionPicker: View {
    @Binding var selection: OverlayPosition
    var compact = false
    var onPick: () -> Void = {}

    @State private var hovered: OverlayPosition?

    var body: some View {
        GeometryReader { geo in
            let menuBar: CGFloat = compact ? 6 : 9
            let pad: CGFloat = compact ? 6 : 10
            let tile = CGSize(width: geo.size.width * 0.24, height: geo.size.width * 0.24 / 1.6)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color(red: 0.20, green: 0.38, blue: 0.86),
                                                Color(red: 0.62, green: 0.32, blue: 0.82),
                                                Color(red: 0.98, green: 0.55, blue: 0.42)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(height: menuBar)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: compact ? 10 : 14,
                                                      topTrailingRadius: compact ? 10 : 14))

                ForEach(OverlayPosition.allCases) { pos in
                    let area = CGSize(width: geo.size.width - 2 * pad,
                                      height: geo.size.height - menuBar - 2 * pad)
                    let x = pad + CGFloat(pos.column) * (area.width - tile.width) / 2
                    let y = menuBar + pad + CGFloat(pos.row) * (area.height - tile.height) / 2
                    cell(pos, size: tile)
                        .offset(x: x, y: y)
                }
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Window position")
    }

    @ViewBuilder
    private func cell(_ pos: OverlayPosition, size: CGSize) -> some View {
        let isSelected = pos == selection
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) { selection = pos }
            onPick()
        } label: {
            ZStack {
                if isSelected {
                    Text(verbatim: "42")
                        .font(.system(size: size.height * 0.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: size.width, height: size.height)
                        .glassEffect(.regular, in: .rect(cornerRadius: size.height * 0.25))
                } else {
                    RoundedRectangle(cornerRadius: size.height * 0.25, style: .continuous)
                        .strokeBorder(.white.opacity(hovered == pos ? 0.9 : 0.45),
                                      style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                        .background(
                            RoundedRectangle(cornerRadius: size.height * 0.25, style: .continuous)
                                .fill(.white.opacity(hovered == pos ? 0.18 : 0.04))
                        )
                        .frame(width: size.width, height: size.height)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? pos : (hovered == pos ? nil : hovered) }
        .help(pos.title)
        .accessibilityLabel(pos.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
