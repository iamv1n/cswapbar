import Foundation

public enum Masking {
    static let bullet: Character = "•"

    /// "you@example.com" → "y••@•••••••.com".
    ///
    /// Keeps the first character and the top-level domain; everything else
    /// becomes bullets. Used only for the individual "Hide emails" setting.
    /// Privacy Mode removes the email entirely.
    public static func email(_ email: String) -> String {
        guard let at = email.lastIndex(of: "@") else {
            return String(repeating: bullet, count: max(email.count, 3))
        }
        let local = email[..<at]
        let domain = email[email.index(after: at)...]

        let maskedLocal = (local.first.map(String.init) ?? "") + String(repeating: bullet, count: max(local.count - 1, 2))

        let maskedDomain: String
        if let dot = domain.lastIndex(of: "."), dot != domain.startIndex {
            let name = domain[..<dot]
            maskedDomain = String(repeating: bullet, count: name.count) + domain[dot...]
        } else {
            maskedDomain = String(repeating: bullet, count: max(domain.count, 3))
        }
        return "\(maskedLocal)@\(maskedDomain)"
    }

    /// "Account 01". Derived from CSwap's slot number (CSwap itself calls slots
    /// "Account-N"), never from the account's real name or email.
    public static func genericLabel(slot: Int) -> String {
        "Account \(slot < 10 ? "0" : "")\(slot)"
    }
}
