import Foundation

/// Splits the account list into fixed-size pages for the popover.
public struct AccountPaging: Equatable, Sendable {
    public static let pageSizeOptions = [3, 4, 5, 6, 8]
    public static let defaultPageSize = 4

    public let pageSize: Int
    public let totalCount: Int

    public init(pageSize: Int, totalCount: Int) {
        self.pageSize = max(1, pageSize)
        self.totalCount = max(0, totalCount)
    }

    public var pageCount: Int { max(1, (totalCount + pageSize - 1) / pageSize) }
    public var isPaged: Bool { pageCount > 1 }

    /// Keeps a page index valid when the account count shrinks.
    public func clamp(_ page: Int) -> Int { min(max(page, 0), pageCount - 1) }

    public func range(forPage page: Int) -> Range<Int> {
        let start = clamp(page) * pageSize
        return start..<min(start + pageSize, totalCount)
    }

    /// "5–8 of 9"
    public func label(forPage page: Int) -> String {
        let range = range(forPage: page)
        guard !range.isEmpty else { return "0 of 0" }
        let first = range.lowerBound + 1
        let last = range.upperBound
        return first == last ? "\(first) of \(totalCount)" : "\(first)–\(last) of \(totalCount)"
    }

    /// Display order: the active account first, then by CSwap slot.
    public static func ordered(_ accounts: [Account]) -> [Account] {
        accounts.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.slot < rhs.slot
        }
    }
}
