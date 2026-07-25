import AppKit
import SwiftUI

struct TimelineScrubber: View {
    @EnvironmentObject private var model: AppModel
    let onCalendarToggle: () -> Void

    @State private var dragStartShift = 0
    @State private var rulerPhase: CGFloat = 0

    private let pointsPerQuarterHour: CGFloat = 5

    var body: some View {
        let palette = model.theme.palette

        ZStack(alignment: .top) {
            palette.background

            RulerTicks(color: palette.ruler, phase: rulerPhase)
                .frame(height: 26)
                .padding(.horizontal, 8)
                .offset(y: 40)
                .allowsHitTesting(false)

            TimelineInteractionSurface(
                onBegan: {
                    dragStartShift = model.shiftMinutes
                },
                onChanged: { translation in
                    model.shiftMinutes = snappedShift(
                        startShift: dragStartShift,
                        translation: translation
                    )
                    rulerPhase = translation.truncatingRemainder(dividingBy: pointsPerQuarterHour)
                },
                onEnded: { predictedTranslation in
                    let finalShift = snappedShift(
                        startShift: dragStartShift,
                        translation: predictedTranslation
                    )
                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.76)) {
                        model.shiftMinutes = finalShift
                        rulerPhase = 0
                    }
                },
                onScroll: { delta in
                    guard abs(delta) > 0.15 else { return }
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.82)) {
                        model.nudge(by: delta > 0 ? -15 : 15)
                        rulerPhase = 0
                    }
                },
                onCenterClick: onCalendarToggle
            )

            if model.shiftMinutes == 0 {
                Button(action: onCalendarToggle) {
                    Circle()
                        .fill(palette.primary.opacity(0.12))
                        .frame(width: 6, height: 6)
                        .contentShape(Rectangle().inset(by: -10))
                }
                .buttonStyle(.plain)
                .offset(y: 20)
                .help("Show calendar")
            } else {
                Button {
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                        model.resetToNow()
                        rulerPhase = 0
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(shiftLabel)
                            .font(.system(size: 10.5, weight: .semibold))
                        Image(systemName: "xmark")
                            .font(.system(size: 7.5, weight: .bold))
                    }
                    .foregroundStyle(model.theme == .daylight ? .white : palette.primary.opacity(0.72))
                    .padding(.horizontal, 8)
                    .frame(height: 19)
                    .background(
                        model.theme == .daylight
                            ? Color.black.opacity(0.30)
                            : Color.white.opacity(0.15),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .offset(y: 9)
                .help("Return to current time")
            }
        }
        .frame(height: 80)
    }

    private func snappedShift(startShift: Int, translation: CGFloat) -> Int {
        let baseDate = model.isLive ? Date() : model.anchorDate
        let minutesPerPoint = 15.0 / Double(pointsPerQuarterHour)
        let rawDate = baseDate.addingTimeInterval(
            TimeInterval(startShift * 60) - Double(translation) * minutesPerPoint * 60
        )
        let snappedInterval = (rawDate.timeIntervalSince1970 / 900).rounded() * 900
        let snappedDate = Date(timeIntervalSince1970: snappedInterval)
        return min(
            10_080,
            max(-10_080, Int((snappedDate.timeIntervalSince(baseDate) / 60).rounded()))
        )
    }

    private var shiftLabel: String {
        let quarterHours = (Double(model.shiftMinutes) / 15).rounded()
        let hours = quarterHours / 4
        let sign = hours >= 0 ? "+" : "−"
        let absolute = abs(hours)
        if absolute.rounded() == absolute {
            return "\(sign)\(Int(absolute))h"
        }
        return "\(sign)\(String(format: "%.2f", absolute).trimmingTrailingZeros)h"
    }
}

private struct RulerTicks: View {
    let color: Color
    let phase: CGFloat

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 5
            let normalizedPhase = phase.truncatingRemainder(dividingBy: spacing)
            let count = Int(size.width / spacing) + 4

            for index in -2..<count {
                let x = CGFloat(index) * spacing + normalizedPhase
                let distanceFromEdge = min(x, size.width - x)
                let fade = min(1, max(0.10, distanceFromEdge / 36))
                let height = tickHeight(at: abs(index))
                let rect = CGRect(
                    x: x,
                    y: (size.height - height) / 2,
                    width: 1.5,
                    height: height
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 0.75),
                    with: .color(color.opacity(fade))
                )
            }
        }
    }

    private func tickHeight(at index: Int) -> CGFloat {
        if index.isMultiple(of: 10) { return 22 }
        if index.isMultiple(of: 5) { return 17 }
        return 14
    }
}

private struct TimelineInteractionSurface: NSViewRepresentable {
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void
    let onScroll: (CGFloat) -> Void
    let onCenterClick: () -> Void

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        update(nsView)
    }

    private func update(_ view: InteractionView) {
        view.onBegan = onBegan
        view.onChanged = onChanged
        view.onEnded = onEnded
        view.onScroll = onScroll
        view.onCenterClick = onCenterClick
    }

    final class InteractionView: NSView {
        var onBegan: () -> Void = {}
        var onChanged: (CGFloat) -> Void = { _ in }
        var onEnded: (CGFloat) -> Void = { _ in }
        var onScroll: (CGFloat) -> Void = { _ in }
        var onCenterClick: () -> Void = {}

        private var startPoint: NSPoint = .zero
        private var lastPoint: NSPoint = .zero
        private var lastTimestamp: TimeInterval = 0
        private var velocity: CGFloat = 0

        override var acceptsFirstResponder: Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            startPoint = convert(event.locationInWindow, from: nil)
            lastPoint = startPoint
            lastTimestamp = event.timestamp
            velocity = 0
            onBegan()
            NSCursor.closedHand.push()
        }

        override func mouseDragged(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            let elapsed = max(0.001, event.timestamp - lastTimestamp)
            velocity = (point.x - lastPoint.x) / CGFloat(elapsed)
            lastPoint = point
            lastTimestamp = event.timestamp
            onChanged(point.x - startPoint.x)
        }

        override func mouseUp(with event: NSEvent) {
            NSCursor.pop()
            let point = convert(event.locationInWindow, from: nil)
            let translation = point.x - startPoint.x
            if abs(translation) < 3,
               abs(point.y - startPoint.y) < 3,
               abs(point.x - bounds.midX) < 18,
               point.y > bounds.height * 0.56 {
                onCenterClick()
                return
            }
            let projectedMomentum = min(80, max(-80, velocity * 0.12))
            let predictedTranslation = translation + projectedMomentum
            onEnded(predictedTranslation)
        }

        override func scrollWheel(with event: NSEvent) {
            let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
                ? event.scrollingDeltaX
                : event.scrollingDeltaY
            onScroll(delta)
        }
    }
}

private extension String {
    var trimmingTrailingZeros: String {
        var value = self
        while value.last == "0" { value.removeLast() }
        if value.last == "." { value.removeLast() }
        return value
    }
}
