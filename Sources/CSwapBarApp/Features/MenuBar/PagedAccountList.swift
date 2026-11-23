import CSwapBarCore
import SwiftUI

/// Accounts shown a page at a time (default 4), with a page switcher when
/// there are more. The active account is always first on page 1.
struct PagedAccountList: View {
    @Bindable var model: AppModel
    @State private var page = 0
    @Environment(\.theme) private var theme

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
        .onChange(of: paging.pageCount) { page = paging.clamp(page) }
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
