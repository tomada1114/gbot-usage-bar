import ClaudeUsageBarCore
import SwiftUI

/// Metrics for the menu bar badge, drawn to sit beside the system's own status items.
///
/// The silhouette follows Clawd, Claude Code's pixel mascot: a body eight pixels wide and
/// six tall, an arm on each side across its middle two rows, and four legs under its
/// first, third, sixth, and eighth columns. The body stretches sideways to fit the
/// number, so only its height and the arms and legs are fixed.
private enum Layout {
    /// About the size of menu bar text, so the digits stay as legible as a clock.
    static let fontSize: CGFloat = 12
    static let horizontalPadding: CGFloat = 3
    static let borderWidth: CGFloat = 1.25
    static let bodyHeight: CGFloat = 15
    /// Keeps a single digit's body wider than tall, as Clawd's is.
    static let minimumBodyWidth: CGFloat = 20
    static let armReach: CGFloat = 3.5
    /// The arms span the body's middle third: rows two and three of six.
    static let armTop: CGFloat = 5
    static let armBottom: CGFloat = 10
    static let legHeight: CGFloat = 4
    static let bodyColumns: CGFloat = 8
    /// The inner leg of each pair, counted from the body's side; the outer one is flush
    /// with it.
    static let innerLegColumn: CGFloat = 2
    /// Caps the legs' thickness, so a three-digit body does not stand on stumps.
    static let maximumLegWidth: CGFloat = 2.5
    /// Rendered at least at Retina density, so the badge stays crisp on a 2x display even
    /// when the label's environment reports 1x.
    static let minimumScale: CGFloat = 2
}

/// Clawd's body and arms as one closed outline. Insettable, so `strokeBorder` keeps the
/// stroke inside the drawing's bounds.
private struct ClawdOutline: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let left = rect.minX + inset
        let right = rect.maxX - inset
        let bodyLeft = rect.minX + Layout.armReach + inset
        let bodyRight = rect.maxX - Layout.armReach - inset
        let top = rect.minY + inset
        let bottom = rect.minY + Layout.bodyHeight - inset
        let armTop = rect.minY + Layout.armTop + inset
        let armBottom = rect.minY + Layout.armBottom - inset
        var path = Path()
        path.addLines([
            CGPoint(x: bodyLeft, y: top),
            CGPoint(x: bodyRight, y: top),
            CGPoint(x: bodyRight, y: armTop),
            CGPoint(x: right, y: armTop),
            CGPoint(x: right, y: armBottom),
            CGPoint(x: bodyRight, y: armBottom),
            CGPoint(x: bodyRight, y: bottom),
            CGPoint(x: bodyLeft, y: bottom),
            CGPoint(x: bodyLeft, y: armBottom),
            CGPoint(x: left, y: armBottom),
            CGPoint(x: left, y: armTop),
            CGPoint(x: bodyLeft, y: armTop),
        ])
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> Self {
        Self(inset: inset + amount)
    }
}

/// Clawd's four legs, filled, hanging from the bottom of the body in `rect`.
private struct ClawdLegs: Shape {
    func path(in rect: CGRect) -> Path {
        let bodyLeft = rect.minX + Layout.armReach
        let bodyRight = rect.maxX - Layout.armReach
        let pitch = (bodyRight - bodyLeft) / Layout.bodyColumns
        let legWidth = min(pitch, Layout.maximumLegWidth)
        // Overlapping the body's bottom stroke joins each leg to it without a seam.
        let top = rect.minY + Layout.bodyHeight - Layout.borderWidth
        var path = Path()
        // Mirrored pairs, so a leg narrower than its column still leaves the outer legs
        // flush with the body's sides.
        for column in [0, Layout.innerLegColumn] {
            for left in [bodyLeft + column * pitch, bodyRight - column * pitch - legWidth] {
                path.addRect(CGRect(x: left, y: top, width: legWidth, height: rect.maxY - top))
            }
        }
        return path
    }
}

/// The number inside Clawd's outline, drawn in one opaque color on clear. Only its alpha
/// matters: the image is a template, which the menu bar tints itself.
private struct BadgeDrawing: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: Layout.fontSize, weight: .semibold).monospacedDigit())
            .padding(.horizontal, Layout.horizontalPadding)
            .frame(
                minWidth: Layout.minimumBodyWidth,
                minHeight: Layout.bodyHeight,
                maxHeight: Layout.bodyHeight,
            )
            .padding(.horizontal, Layout.armReach)
            .padding(.bottom, Layout.legHeight)
            .overlay {
                ZStack {
                    ClawdOutline()
                        .strokeBorder(style: StrokeStyle(
                            lineWidth: Layout.borderWidth,
                            lineJoin: .miter,
                        ))
                    ClawdLegs()
                }
            }
            .foregroundStyle(.black)
    }
}

/// The menu bar badge for one presentation.
///
/// A `MenuBarExtra` label renders only a `Text` or an `Image`, so the outlined number is
/// rendered into an image first. Marking it a template is what lets it follow the menu
/// bar: dark on a light bar, light on a dark one, inverted while the menu is open.
struct UsageBadge: View {
    let presentation: UsagePresentation

    @Environment(\.displayScale)
    private var displayScale

    var body: some View {
        Image(nsImage: image)
            .accessibilityLabel(Text(presentation.badgeAccessibilityLabel))
    }

    private var image: NSImage {
        let renderer = ImageRenderer(content: BadgeDrawing(text: presentation.badgeText))
        renderer.scale = max(displayScale, Layout.minimumScale)
        let rendered = renderer.nsImage ?? NSImage()
        rendered.isTemplate = true
        // The status item's button reads this, not the SwiftUI label, for VoiceOver.
        rendered.accessibilityDescription = String(localized: presentation.badgeAccessibilityLabel)
        return rendered
    }
}

@MainActor
private enum PreviewState {
    static let formatter = UsageFormatter()

    static func badge(percent: Double?) -> UsageBadge {
        let snapshot = percent.map { utilization in
            UsageSnapshot(
                fiveHour: nil,
                sevenDay: UsageWindow(utilization: utilization, resetsAt: nil),
            )
        }
        return UsageBadge(presentation: UsagePresentation(
            state: UsageState(snapshot: snapshot),
            formatter: formatter,
        ))
    }
}

/// The app's menu bar label: the usage badge for the chosen window, kept current by the
/// view model.
public struct UsageBadgeLabel: View {
    private let model: UsageMenuViewModel

    public var body: some View {
        UsageBadge(presentation: model.presentation)
    }

    /// `App/` builds the model, because its ports need `ClaudeUsageBarPlatform`'s adapters.
    public init(model: UsageMenuViewModel) {
        self.model = model
    }
}

#Preview("Badges") {
    HStack {
        PreviewState.badge(percent: 76)
        PreviewState.badge(percent: 5)
        PreviewState.badge(percent: 100)
        PreviewState.badge(percent: nil)
    }
    .padding()
}
