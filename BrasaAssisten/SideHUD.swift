import SwiftUI

/// Small, persistent native HUD. This view is independent of the website:
/// it only displays cards and advice already approved by PageReader/PokerCoach.
/// No web content is hidden, restyled or re-parented.
struct SideHUD: View {
    let phase: String
    let personalCards: [String]
    let communityCards: [String]
    let observing: Bool
    let reviewNeeded: Bool
    let tone: String
    let action: String
    let viewportHeight: CGFloat

    @Binding var collapsed: Bool
    @Binding var onLeft: Bool
    @Binding var verticalOffset: Double

    let openAnalysis: () -> Void

    @GestureState private var verticalDrag: CGFloat = 0

    private let gold = Color(red: 0.99, green: 0.72, blue: 0.27)
    private let dark = Color(red: 0.09, green: 0.064, blue: 0.074)

    private var color: Color {
        guard !reviewNeeded else { return gold }
        switch tone {
        case "red": return Color(red: 0.94, green: 0.23, blue: 0.27)
        case "yellow": return Color(red: 1.0, green: 0.70, blue: 0.20)
        case "green": return Color(red: 0.14, green: 0.80, blue: 0.38)
        default: return gold
        }
    }

    private var status: String {
        if reviewNeeded { return "CONFERIR" }
        if personalCards.count == 2 { return "LENDO" }
        if !communityCards.isEmpty || observing { return "OBSERVANDO" }
        return "AGUARDANDO"
    }

    private var signalLabel: String {
        guard !reviewNeeded else { return "INCOMPLETA" }
        switch tone {
        case "red": return "DESISTIR"
        case "yellow": return "CAUTELA"
        case "green": return "FORTE"
        default: return "ANALISANDO"
        }
    }

    private var activeHeight: Double {
        collapsed ? 52 : 190
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .rotationEffect(.degrees(90))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white.opacity(0.62))
            .frame(width: 22, height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .updating($verticalDrag) { value, current, _ in
                        current = value.translation.height
                    }
                    .onEnded { value in
                        let next = verticalOffset + Double(value.translation.height)
                        verticalOffset = SideHUDPlacement.clamp(
                            next,
                            viewportHeight: Double(viewportHeight),
                            hudHeight: activeHeight
                        )
                    }
            )
            .accessibilityLabel("Arrastar painel para cima ou para baixo")
    }

    private var wideContent: some View {
        VStack(spacing: 7) {
            HStack(spacing: 0) {
                dragHandle
                Spacer(minLength: 0)
                Button {
                    onLeft.toggle()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 21, height: 27)
                }
                .accessibilityLabel("Mover painel para a outra lateral")
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        collapsed = true
                    }
                    verticalOffset = SideHUDPlacement.clamp(
                        verticalOffset,
                        viewportHeight: Double(viewportHeight),
                        hudHeight: 52
                    )
                } label: {
                    Image(systemName: onLeft ? "chevron.left" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 22, height: 27)
                }
                .accessibilityLabel("Recolher painel")
            }
            .foregroundStyle(gold)

            VStack(spacing: 2) {
                Text(phase.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(personalCards.count == 2
                     ? personalCards.joined(separator: " ")
                     : "— —")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                if !communityCards.isEmpty {
                    Text(communityCards.joined(separator: " "))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(gold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                }
            }

            Text(signalLabel)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(color, in: RoundedRectangle(cornerRadius: 6))

            Text(status)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Button(action: openAnalysis) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .background(.white.opacity(0.065),
                                in: RoundedRectangle(cornerRadius: 7))
            }
            .accessibilityLabel("Abrir análise completa do BrasaAssisten")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(width: SideHUDPlacement.fullWidth)
        .fixedSize(horizontal: true, vertical: true)
        .foregroundStyle(.white)
        .background(dark.opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(gold.opacity(0.85), lineWidth: 1.1))
        .shadow(color: .black.opacity(0.45), radius: 8)
    }

    private var narrowContent: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                collapsed = false
            }
            verticalOffset = SideHUDPlacement.clamp(
                verticalOffset,
                viewportHeight: Double(viewportHeight),
                hudHeight: 190
            )
        } label: {
            VStack(spacing: 4) {
                Image(systemName: onLeft ? "chevron.right" : "chevron.left")
                    .font(.system(size: 9, weight: .bold))
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 5, height: 15)
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
            }
            .foregroundStyle(gold)
            .frame(width: SideHUDPlacement.collapsedWidth, height: 52)
            .background(dark.opacity(0.96),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(gold.opacity(0.75), lineWidth: 1))
        }
        .accessibilityLabel("Expandir aba do BrasaAssisten")
    }

    var body: some View {
        Group {
            if collapsed {
                narrowContent
            } else {
                wideContent
            }
        }
        // The offset is applied only to the HUD, never to the browser.
        .offset(y: CGFloat(verticalOffset) + verticalDrag)
        .animation(.easeInOut(duration: 0.2), value: collapsed)
        .animation(.easeInOut(duration: 0.2), value: onLeft)
    }
}
