import LifegamesTokens
import SwiftUI

// MARK: - Launch Backdrop

//
// A single token-pure, looping neon backdrop for the Launch / Login screens: a
// video "buffering" play-ring. Drawing is factored into an explicitly-typed
// static helper so the Canvas body stays trivial for the Swift type-checker
// (a fat Canvas closure timed out on CI's toolchain).

/// Neon palette for the backdrop's orbiting motes.
public enum OMDNeon {
  public static let palette: [Color] = [
    LGColor.accentCyan,
    LGColor.accentBlue,
    LGColor.accentPink,
    LGColor.accentGreen,
    LGColor.accentAmber,
    LGColor.accentPurple,
  ]

  public static func color(_ index: Int) -> Color {
    let count = palette.count
    return palette[((index % count) + count) % count]
  }
}

// MARK: - Buffer Ring (play glyph + sweeping loader)

/// A central play triangle inside a circular track, with a cyan→pink gradient
/// arc sweeping around it like a video buffering indicator, orbiting colored
/// motes, and a soft halo that expands to fill the space.
public struct BufferRingAnimation: View {
  public init() {}

  public var body: some View {
    TimelineView(.animation) { context in
      Canvas { ctx, size in
        Self.draw(in: &ctx, size: size, t: context.date.timeIntervalSinceReferenceDate)
      }
    }
    .blendMode(.screen)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private static func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = min(size.width, size.height) * 0.2

    // Faint full track ring.
    let trackRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    ctx.stroke(Path(ellipseIn: trackRect), with: .color(LGColor.accentBlue.opacity(0.16)), lineWidth: 3)

    // Sweeping buffer arc with a cyan→pink gradient.
    let sweep = (t / 1.6).truncatingRemainder(dividingBy: 1.0)
    let start = Angle(radians: sweep * 2 * Double.pi - Double.pi / 2)
    let end = Angle(radians: (sweep + 0.3) * 2 * Double.pi - Double.pi / 2)
    var arc = Path()
    arc.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    ctx.stroke(
      arc,
      with: .linearGradient(
        Gradient(colors: [LGColor.accentCyan, LGColor.accentPink]),
        startPoint: CGPoint(x: center.x - radius, y: center.y),
        endPoint: CGPoint(x: center.x + radius, y: center.y)
      ),
      style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
    )

    // Orbiting colored motes around the ring.
    for i in 0 ..< 6 {
      let a = sweep * 2 * Double.pi + Double(i) / 6 * 2 * Double.pi
      let p = CGPoint(x: center.x + CGFloat(cos(a)) * radius, y: center.y + CGFloat(sin(a)) * radius)
      let dotRect = CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)
      ctx.fill(Path(ellipseIn: dotRect), with: .color(OMDNeon.color(i).opacity(0.85)))
    }

    // Center play triangle with a cyan→blue gradient.
    let s = radius * 0.55
    var tri = Path()
    tri.move(to: CGPoint(x: center.x - s * 0.4, y: center.y - s * 0.62))
    tri.addLine(to: CGPoint(x: center.x - s * 0.4, y: center.y + s * 0.62))
    tri.addLine(to: CGPoint(x: center.x + s * 0.72, y: center.y))
    tri.closeSubpath()
    ctx.fill(
      tri,
      with: .linearGradient(
        Gradient(colors: [LGColor.accentCyan, LGColor.accentBlue]),
        startPoint: CGPoint(x: center.x - s, y: center.y),
        endPoint: CGPoint(x: center.x + s, y: center.y)
      )
    )

    // Expanding halo ring, pink-tinted.
    let halo = (t / 2.6).truncatingRemainder(dividingBy: 1.0)
    let hr = radius + CGFloat(halo) * radius * 1.8
    let haloRect = CGRect(x: center.x - hr, y: center.y - hr, width: hr * 2, height: hr * 2)
    ctx.stroke(Path(ellipseIn: haloRect), with: .color(LGColor.accentPink.opacity((1.0 - halo) * 0.26)), lineWidth: 1.5)
  }
}

#Preview("Buffer Ring") {
  ZStack {
    LGColor.surfaceBase.ignoresSafeArea()
    BufferRingAnimation()
      .frame(width: 220, height: 220)
  }
  .preferredColorScheme(.dark)
}
