import CSwapBarCore
import SwiftUI

/// Accounts shown a page at a time (default 4), with a page switcher when
/// there are more. The active account is always first on page 1.
struct PagedAccountList: View {
    @Bindable var model: AppModel
    @State private var page = 0
    /// Keyboard highlight. Nil until an arrow key is pressed, so mouse users never see it.
    @State private var selection: AccountID?
    @Environment(\.theme) private var theme
    @Environment(\.isSnapshot) private var isSnapshot

    private var ordered: [Account] { AccountPaging.ordered(model.accounts) }
    private var paging: AccountPaging {
        AccountPaging(pageSize: model.settings.accountsPerPage, totalCount: ordered.count)
    }

    var body: some View {
        let paging = paging
        let current = paging.clamp(page)
        let accounts = Array(ordered[paging.range(forPage: current)])

        VStack(spacing: 0) {
            // Countdowns tick without re-running CSwap.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(spacing: theme.layout == .list ? 6 : (theme.compact ? 8 : 10)) {
                    ForEach(accounts) { account in
                        AccountCard(
                            account: account,
                            presentation: model.presentation(for: account),
                            thresholds: model.thresholds,
                            switchState: model.switchState,
                            switchingDisabled: model.isSwitching,
                            now: context.date
                        ) {
                            Task { await model.switchTo(account) }
                        }
                        .overlay {
                            if selection == account.id {
                                RoundedRectangle(cornerRadius: theme.cardRadius + 3, style: .continuous)
                                    .strokeBorder(theme.accent, lineWidth: 2)
                                    .padding(-3)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, paging.isPaged ? 8 : 14)
                .id(current)
                .transition(.opacity)
            }

            if paging.isPaged {
                PageSwitcher(paging: paging, page: current) { newPage in
                    withAnimation(.easeInOut(duration: 0.15)) { page = newPage }
                }
                .padding(.bottom, 10)
            }
        }
        .background { if !isSnapshot { keyboardControls } }
        .onChange(of: paging.pageCount) { page = paging.clamp(page) }
        .onDisappear { selection = nil }
    }

    // MARK: Keyboard

    /// Invisible buttons that carry the popover's keyboard shortcuts:
    /// ↑/↓ move the highlight (across pages), Return switches to it, ⌘1–⌘9 switch directly.
    private var keyboardControls: some View {
        ZStack {
            Button("Previous account") { move(by: -1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("Next account") { move(by: 1) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("Switch to highlighted account") { switchToSelection() }.keyboardShortcut(.return, modifiers: [])
            ForEach(1...9, id: \.self) { number in
                Button("Switch to account \(number)") { switchToAccount(at: number - 1) }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
            }
        }
        .buttonStyle(.plain)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func move(by step: Int) {
        let list = ordered
        guard !list.isEmpty else { return }
        let index: Int
        if let selection, let current = list.firstIndex(where: { $0.id == selection }) {
            index = min(max(current + step, 0), list.count - 1)
        } else {
            // First press starts on the first account of the visible page.
            index = paging.range(forPage: paging.clamp(page)).lowerBound
        }
        select(index, in: list)
    }

    private func select(_ index: Int, in list: [Account]) {
        selection = list[index].id
        let newPage = index / max(paging.pageSize, 1)
        if newPage != page {
            withAnimation(.easeInOut(duration: 0.15)) { page = newPage }
        }
    }

    private func switchToSelection() {
        guard let selection, let account = ordered.first(where: { $0.id == selection }) else { return }
        guard !account.isActive, !model.isSwitching else { return }
        Task { await model.switchTo(account) }
    }

    private func switchToAccount(at index: Int) {
        let list = ordered
        guard list.indices.contains(index) else { return }
        select(index, in: list)
        switchToSelection()
    }
}

/// ‹ ● ○ ○ ›  5–8 of 9
struct PageSwitcher: View {
    let paging: AccountPaging
    let page: Int
    let onChange: (Int) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Button { onChange(page - 1) } label: {
                Image(systemName: "chevron.left").frame(width: 20, height: 20)
            }
            .buttonStyle(.quiet)
            .disabled(page == 0)
            .keyboardShortcut(.leftArrow, modifiers: [])
            .help("Previous page (←)")

            HStack(spacing: 6) {
                ForEach(0..<paging.pageCount, id: \.self) { index in
                    Button { onChange(index) } label: {
                        Circle()
                            .fill(index == page ? theme.accent : theme.border)
                            .frame(width: 7, height: 7)
                            .padding(3)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Page \(index + 1)")
                    .accessibilityAddTraits(index == page ? .isSelected : [])
                }
            }

            Button { onChange(page + 1) } label: {
                Image(systemName: "chevron.right").frame(width: 20, height: 20)
            }
            .buttonStyle(.quiet)
            .disabled(page >= paging.pageCount - 1)
            .keyboardShortcut(.rightArrow, modifiers: [])
            .help("Next page (→)")

            Text(paging.label(forPage: page))
                .font(theme.type.footnote.monospacedDigit())
                .foregroundStyle(theme.muted)
        }
        .foregroundStyle(theme.muted)
        .frame(maxWidth: .infinity)
    }
}
