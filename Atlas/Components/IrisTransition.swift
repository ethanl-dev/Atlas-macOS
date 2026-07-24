import SwiftUI

/// Drives a cinematic "iris / curtains" page transition:
/// close (curtain irises shut over the current view) → swap content → open
/// (curtain irises back out, revealing the new view). Modeled on the Motion
/// `curtains: iris` effect, rebuilt natively so it can bridge the native star
/// map and the WebView-backed world builder.
@MainActor
final class IrisTransition: ObservableObject {
    /// 1 = fully open (screen revealed, curtain hidden) · 0 = fully closed (curtain covers screen).
    @Published var progress: CGFloat = 1
    @Published private(set) var isActive = false
    @Published var origin: UnitPoint = .center

    var closeDuration: Double = 0.42
    var openDuration: Double = 0.54
    var holdDuration: Double = 0.06

    /// Run a full close → swap → open cycle. `swap` fires while the curtain
    /// fully covers the screen, so the underlying view change is never seen.
    func run(from origin: UnitPoint = .center, swap: @escaping () -> Void) {
        guard !isActive else { return }
        self.origin = origin
        progress = 1
        isActive = true

        withAnimation(.easeIn(duration: closeDuration)) { progress = 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + closeDuration) { [weak self] in
            guard let self else { return }
            swap()
            DispatchQueue.main.asyncAfter(deadline: .now() + self.holdDuration) {
                withAnimation(.easeOut(duration: self.openDuration)) { self.progress = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + self.openDuration + 0.05) {
                    self.isActive = false
                }
            }
        }
    }
}

/// Full-window overlay that renders the iris curtain. Place at the top of a
/// ZStack, above all content.
struct IrisCurtain: View {
    @ObservedObject var iris: IrisTransition
    var color: Color = Color(red: 0.012, green: 0.013, blue: 0.023)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width * iris.origin.x,
                                 y: size.height * iris.origin.y)
            let maxR = maxRadius(in: size, from: center)
            let r = max(0, maxR * iris.progress)

            ZStack {
                // Curtain: solid fill everywhere except the circular iris hole.
                color
                    .mask(
                        ZStack {
                            Rectangle().fill(Color.white)
                            Circle()
                                .fill(Color.white)
                                .frame(width: r * 2, height: r * 2)
                                .position(center)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )

                // Aperture edge: a ring of light tracing the iris, brightest mid-transition.
                Circle()
                    .stroke(Color.white.opacity(edgeOpacity), lineWidth: 1.5)
                    .frame(width: r * 2, height: r * 2)
                    .position(center)
                    .shadow(color: Color.white.opacity(edgeOpacity * 0.7), radius: 20)
                    .blur(radius: 0.4)
                    .blendMode(.plusLighter)
            }
            .ignoresSafeArea()
            .allowsHitTesting(iris.isActive)
            .opacity(iris.isActive ? 1 : 0)
        }
        .ignoresSafeArea()
    }

    /// Ring fades to nothing at fully open / fully closed, peaks at the midpoint.
    private var edgeOpacity: Double {
        let p = Double(iris.progress)
        return (1 - abs(p * 2 - 1)) * 0.9
    }

    private func maxRadius(in size: CGSize, from p: CGPoint) -> CGFloat {
        let dx = max(p.x, size.width - p.x)
        let dy = max(p.y, size.height - p.y)
        return (dx * dx + dy * dy).squareRoot()
    }
}
