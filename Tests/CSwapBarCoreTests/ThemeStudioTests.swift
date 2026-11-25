import Foundation
import Testing
@testable import CSwapBarCore

@Suite("Custom themes and design options")
struct ThemeStudioTests {
    let nightfall = CustomTheme(name: "Nightfall", isDark: true, background: 0x12151C, surface: 0x1D212B,
                                text: 0xECEEF3, accent: 0x7AA2F7)

    @Test func hexParsingAndFormatting() {
        #expect(ColorMath.parseHex("#7aa2f7") == 0x7AA2F7)
        #expect(ColorMath.parseHex("7AA2F7") == 0x7AA2F7)
        #expect(ColorMath.parseHex("#fff") == 0xFFFFFF)
        #expect(ColorMath.parseHex("#12345") == nil)
        #expect(ColorMath.parseHex("zzzzzz") == nil)
        #expect(ColorMath.hexString(0x0A0B0C) == "#0A0B0C")
        #expect(ColorMath.mix(0x000000, 0xFFFFFF, 0.5) == 0x808080)
    }

    @Test func derivedPaletteIsReadable() {
        let palette = nightfall.palette
        #expect(palette.style == .solid)
        #expect(palette.backgroundEnd == nil)
        #expect(ColorContrast.ratio(palette.muted, palette.surface) >= 4.5)
        #expect(nightfall.readabilityIssues.isEmpty)

        var gradient = nightfall
        gradient.gradient = true
        gradient.backgroundEnd = 0x2A1E3D
        #expect(gradient.palette.style == .gradient)
        #expect(gradient.palette.backgroundEnd == 0x2A1E3D)
    }

    @Test func mutedTextStaysReadableEvenWithLowContrastColors() {
        let dim = CustomTheme(name: "Dim", isDark: true, background: 0x202020, surface: 0x303030, text: 0x707070, accent: 0x404040)
        // Text itself is under 4.5:1, so muted falls back to the text color rather than going lower.
        #expect(dim.palette.muted == dim.text)
        let messages = dim.readabilityIssues.map(\.message)
        #expect(messages.contains("Text on cards is hard to read"))
        #expect(messages.contains("The accent is hard to see on cards"))
    }

    @Test func exportImportRoundTripMakesANewTheme() throws {
        let data = try nightfall.exportData()
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"format\" : \"cswapbar-theme\""))
        #expect(json.contains("\"accent\" : \"#7AA2F7\""))
        #expect(!json.contains("\"id\""))

        let imported = try CustomTheme.importing(data, existing: [nightfall])
        #expect(imported.id != nightfall.id)
        #expect(imported.name == "Nightfall 2")
        #expect(imported.accent == nightfall.accent && imported.surface == nightfall.surface)
    }

    @Test func importRejectsOtherFilesAndNewerVersions() {
        #expect(throws: CustomTheme.FileError.notATheme) {
            try CustomTheme.importing(Data(##"{"format":"something-else","background":"#000000"}"##.utf8))
        }
        #expect(throws: CustomTheme.FileError.newerVersion(9)) {
            try CustomTheme.importing(Data(#"{"format":"cswapbar-theme","version":9}"#.utf8))
        }
        #expect(throws: CustomTheme.FileError.badColor("surface")) {
            try CustomTheme.importing(Data(##"{"background":"#000","surface":"blue","text":"#fff","accent":"#f00"}"##.utf8))
        }
    }

    @Test func namesAreCleanedAndUnique() {
        #expect(CustomTheme(name: "   ", isDark: true, background: 0, surface: 0, text: 0, accent: 0).name == "Custom Theme")
        #expect(CustomTheme(name: String(repeating: "x", count: 99), isDark: true, background: 0, surface: 0, text: 0, accent: 0).name.count
                == CustomTheme.maxNameLength)
        var second = nightfall
        second.name = "Nightfall 2"
        #expect(CustomTheme.uniqueName("Nightfall", existing: [nightfall, second]) == "Nightfall 3")
        #expect(CustomTheme.uniqueName("Fresh", existing: [nightfall]) == "Fresh")
    }

    @Test func settingsSelectAndDeleteCustomThemes() throws {
        var settings = AppSettings()
        settings.theme = .paper
        settings.addCustomTheme(nightfall)
        #expect(settings.activeCustomTheme == nightfall)
        #expect(settings.activePalette(systemIsDark: false).name == "Nightfall")
        #expect(!settings.followsSystemAppearance)

        settings.selectBuiltInTheme(.system)
        #expect(settings.activeCustomTheme == nil)
        #expect(settings.followsSystemAppearance)
        #expect(settings.customThemes.count == 1)

        settings.customThemeID = nightfall.id
        settings.deleteCustomTheme(id: nightfall.id)
        #expect(settings.customThemes.isEmpty && settings.customThemeID == nil)
    }

    @Test func settingsRoundTripAndSkipBrokenThemes() throws {
        var settings = AppSettings()
        settings.design.corners = .boxy
        settings.design.borders = .bold
        settings.design.bars = .thick
        settings.design.controls = .matchCorners
        settings.addCustomTheme(nightfall)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)

        let partlyBroken = ##"""
        {"design":{"corners":"wobbly","bars":"thick"},
         "customThemes":[{"name":"Bad","background":"nope"},
                         {"name":"Good","background":"#111111","surface":"#222222","text":"#EEEEEE","accent":"#FF8800"}]}
        """##
        let lenient = try JSONDecoder().decode(AppSettings.self, from: Data(partlyBroken.utf8))
        #expect(lenient.design.corners == .themeDefault)
        #expect(lenient.design.bars == .thick)
        #expect(lenient.customThemes.map(\.name) == ["Good"])
    }

    @Test func cornerAndBarScales() {
        #expect(CornerStyle.themeDefault.cardRadius(themeDefault: 18) == 18)
        #expect(CornerStyle.boxy.cardRadius(themeDefault: 18) < CornerStyle.round.cardRadius(themeDefault: 18))
        #expect(CornerStyle.allCases.allSatisfy { $0.widgetRadius(themeDefault: 22) >= $0.cardRadius(themeDefault: 14) || $0 == .themeDefault })
        #expect(BarThickness.thin.scale < BarThickness.regular.scale && BarThickness.regular.scale < BarThickness.thick.scale)
        #expect(BorderWeight.none.lineWidth == 0 && BorderWeight.themeDefault.lineWidth == nil)
    }
}

@Suite("Updates")
struct UpdateTests {
    private func release(tag: String, draft: Bool = false, prerelease: Bool = false, assets: [String]? = nil) throws -> GitHubRelease {
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let names = assets ?? ["CSwapBar-\(version).dmg", "CSwapBar-\(version).zip", "CSwapBar-\(version).zip.sha256"]
        let assetJSON = names.map {
            #"{"name":"\#($0)","size":100,"browser_download_url":"https://github.com/iamv1n/cswapbar/releases/download/\#(tag)/\#($0)"}"#
        }.joined(separator: ",")
        let json = #"""
        {"tag_name":"\#(tag)","name":"CSwapBar \#(version)","body":"  Notes here.\n","draft":\#(draft),"prerelease":\#(prerelease),
         "html_url":"https://github.com/iamv1n/cswapbar/releases/tag/\#(tag)","published_at":"2026-12-01T10:00:00Z",
         "assets":[\#(assetJSON)],"extra_field":{"ignored":true}}
        """#
        return try GitHubRelease.decode(Data(json.utf8))
    }

    @Test func versionsCompare() throws {
        let v = { (s: String) in AppVersion(s)! }
        #expect(v("v0.2.0") > v("0.1.9"))
        #expect(v("1.0") == v("1.0.0"))
        #expect(v("0.10.0") > v("0.9.9"))
        #expect(v("0.2.0-beta.2") < v("0.2.0"))
        #expect(v("0.2.0-beta.10") > v("0.2.0-beta.2"))
        #expect(AppVersion("banana") == nil)
        #expect(AppVersion("1.2.3.4") == nil)
        #expect(v("v1.2.3-rc.1").description == "1.2.3-rc.1")
    }

    @Test func newerReleaseIsOffered() throws {
        let update = try #require(AvailableUpdate.from(release(tag: "v0.2.0"), current: AppVersion("0.1.0")!))
        #expect(update.version.description == "0.2.0")
        #expect(update.canInstall)
        #expect(update.archive?.name == "CSwapBar-0.2.0.zip")
        #expect(update.notes == "Notes here.")
        #expect(update.publishedAt != nil)
    }

    @Test func sameOlderDraftAndPreReleasesAreNotOffered() throws {
        let current = AppVersion("0.2.0")!
        #expect(AvailableUpdate.from(try release(tag: "v0.2.0"), current: current) == nil)
        #expect(AvailableUpdate.from(try release(tag: "v0.1.5"), current: current) == nil)
        #expect(AvailableUpdate.from(try release(tag: "v0.3.0", draft: true), current: current) == nil)
        #expect(AvailableUpdate.from(try release(tag: "v0.3.0-beta.1", prerelease: true), current: current) == nil)
        // A beta build does get newer betas.
        #expect(AvailableUpdate.from(try release(tag: "v0.3.0-beta.2", prerelease: true), current: AppVersion("0.3.0-beta.1")!) != nil)
    }

    @Test func releaseWithoutZipCanOnlyBeDownloadedByHand() throws {
        let update = try #require(AvailableUpdate.from(release(tag: "v0.2.0", assets: ["CSwapBar-0.2.0.dmg"]), current: AppVersion("0.1.0")!))
        #expect(!update.canInstall)
    }

    @Test func checksumFileParsing() {
        let digest = String(repeating: "ab", count: 32)
        #expect(Checksum.sha256(fromChecksumFile: "\(digest)  CSwapBar-0.2.0.zip\n", fileName: "CSwapBar-0.2.0.zip") == digest)
        #expect(Checksum.sha256(fromChecksumFile: "\(digest.uppercased()) *CSwapBar-0.2.0.zip", fileName: "CSwapBar-0.2.0.zip") == digest)
        #expect(Checksum.sha256(fromChecksumFile: digest, fileName: "anything") == digest)
        #expect(Checksum.sha256(fromChecksumFile: "\(digest)  Other.zip", fileName: "CSwapBar-0.2.0.zip") == nil)
        #expect(Checksum.sha256(fromChecksumFile: "not-a-digest  CSwapBar-0.2.0.zip", fileName: "CSwapBar-0.2.0.zip") == nil)
    }

    @Test func updatePreferencesDecodeLeniently() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"updates":{"installAutomatically":true}}"#.utf8))
        #expect(decoded.updates.checkAutomatically)
        #expect(decoded.updates.installAutomatically)
        #expect(decoded.updates.skippedVersion == nil)
    }
}
