import AppKit
import CSwapBarCore
import SwiftUI

/// Shown in Settings → General when CSwap's own menu-bar app (`cswap menubar`) is also running.
struct CSwapMenubarNotice: View {
    let status: CSwapMenubarStatus
    @Environment(\.theme) private var theme
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle")
                    .font(theme.type.icon(16, .semibold))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.isRunning ? "CSwap's own menu bar app is also running" : "CSwap's own menu bar app is installed")
                        .font(theme.type.title)
                        .foregroundStyle(theme.text)
                    Text(status.explanation + (status.startsAtLogin ? " It starts at login." : ""))
                        .font(theme.type.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 10) {
                Text("To remove it:")
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
                Text(CSwapMenubarStatus.removeCommand)
                    .font(theme.type.font(12, .medium).monospaced())
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Spacer(minLength: 0)
                Button(copied ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(CSwapMenubarStatus.removeCommand, forType: .string)
                    copied = true
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .card()
    }
}
