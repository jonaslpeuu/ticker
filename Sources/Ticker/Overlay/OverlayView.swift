import SwiftUI

/// The number inside the glass panel. Sized relative to the panel height.
struct OverlayView: View {
    let counter: Counter
    let overlay: OverlayController

    var body: some View {
        GeometryReader { geo in
            Text(verbatim: "\(counter.value)")
                .font(.system(size: geo.size.height * 0.58, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.15)
                .contentTransition(.numericText(value: Double(counter.value)))
                .foregroundStyle(overlay.textIsWhite ? Color.white : Color.black)
                .shadow(color: (overlay.textIsWhite ? Color.black : Color.white).opacity(0.18), radius: 6, y: 1)
                .padding(.horizontal, geo.size.height * 0.14)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
