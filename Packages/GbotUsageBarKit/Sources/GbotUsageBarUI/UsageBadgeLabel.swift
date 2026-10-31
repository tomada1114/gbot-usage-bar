import GbotUsageBarCore
import SwiftUI

/// Metrics for the menu bar badge, drawn to sit beside the system's own status items:
/// the number inside a thin rounded rectangle.
private enum Layout {
    /// About the size of menu bar text, so the digits stay as legible as a clock.
    static let fontSize: CGFloat = 12
    static let horizontalPadding: CGFloat = 4
    static let borderWidth: CGFloat = 1.25
    static let cornerRadius: CGFloat = 4
    static let height: CGFloat = 16
    /// Keeps a single digit's badge wider than tall.
    static let minimumWidth: CGFloat = 22
    /// Rendered at least at Retina density, so the badge stays crisp on a 2x display even
    /// when the label's environment reports 1x.
    static let minimumScale: CGFloat = 2
}

/// The number inside its outline, drawn in one opaque color on clear. Only its alpha
/// matters: the image is a template, which the menu bar tints itself.
private struct BadgeDrawing: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: Layout.fontSize, weight: .semibold).monospacedDigit())
            .padding(.horizontal, Layout.horizontalPadding)
            .frame(
                minWidth: Layout.minimumWidth,
                minHeight: Layout.height,
                maxHeight: Layout.height,
            )
            .overlay {
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .strokeBorder(lineWidth: Layout.borderWidth)
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
        let weekly = percent.map { UsageWindow(utilization: $0, resetsAt: nil) }
        return UsageBadge(presentation: UsagePresentation(
            state: UsageState(weekly: weekly),
            formatter: formatter,
            now: .now,
        ))
    }
}

/// The app's menu bar label: the weekly usage badge, kept current by the view model.
public struct UsageBadgeLabel: View {
    private let model: UsageMenuViewModel

    public var body: some View {
        UsageBadge(presentation: model.presentation)
    }

    /// `App/` builds the model, because its ports need `GbotUsageBarPlatform`'s adapters.
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
