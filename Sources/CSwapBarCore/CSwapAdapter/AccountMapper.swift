import Foundation

/// Converts CSwap DTOs into domain models.
enum AccountMapper {
    static func account(from dto: CSwapAccountDTO, activeNumber: Int?) -> Account? {
        // `status` can report an unmanaged live login with no slot; it can't be switched to.
        guard let slot = dto.number else { return nil }

        let orgUUID = dto.organizationUuid ?? ""
        let isActive = dto.active ?? (activeNumber == slot)
        return Account(
            id: AccountID(email: dto.email, organizationUUID: orgUUID),
            slot: slot,
            email: dto.email,
            alias: nonEmpty(dto.alias),
            organizationName: nonEmpty(dto.organizationName),
            isOrganization: dto.isOrganization ?? !orgUUID.isEmpty,
            isActive: isActive,
            isDisabled: dto.disabled ?? false,
            plan: dto.plan.map(plan(from:)),
            usage: usage(from: dto),
            usageStatus: UsageStatus(raw: dto.usageStatus),
            usageError: nonEmpty(dto.usageError),
            loginExpiresAt: CSwapDate.parse(dto.loginExpiresAt)
        )
    }

    static func snapshot(from dto: CSwapListDTO, capturedAt: Date) -> AccountSnapshot {
        let accounts = (dto.accounts ?? [])
            .compactMap { account(from: $0, activeNumber: dto.activeAccountNumber) }
            .sorted { $0.slot < $1.slot }
        return AccountSnapshot(accounts: accounts, capturedAt: capturedAt)
    }

    private static func usage(from dto: CSwapAccountDTO) -> Usage? {
        if let usage = dto.usage {
            return makeUsage(usage, fetchedAt: dto.usageFetchedAt, isLastKnown: false)
        }
        if let lastGood = dto.lastGoodUsage {
            return makeUsage(lastGood, fetchedAt: dto.lastGoodFetchedAt, isLastKnown: true)
        }
        return nil
    }

    private static func makeUsage(_ dto: CSwapUsageDTO, fetchedAt: String?, isLastKnown: Bool) -> Usage {
        Usage(
            fiveHour: dto.fiveHour.map(window(from:)),
            sevenDay: dto.sevenDay.map(window(from:)),
            scoped: (dto.scoped ?? []).map(window(from:)),
            fetchedAt: CSwapDate.parse(fetchedAt),
            isLastKnown: isLastKnown
        )
    }

    private static func window(from dto: CSwapWindowDTO) -> UsageWindow {
        UsageWindow(
            percent: dto.pct.map { min(max($0, 0), 100) },
            resetsAt: CSwapDate.parse(dto.resetsAt),
            name: nonEmpty(dto.name)
        )
    }

    private static func plan(from dto: CSwapPlanDTO) -> SubscriptionPlan {
        SubscriptionPlan(
            label: nonEmpty(dto.planDisplayName) ?? nonEmpty(dto.label),
            tier: nonEmpty(dto.tier),
            subscriptionStatus: nonEmpty(dto.subscriptionStatus),
            isExpired: dto.expired ?? false
        )
    }

    private static func nonEmpty(_ string: String?) -> String? {
        guard let string, !string.isEmpty else { return nil }
        return string
    }
}
