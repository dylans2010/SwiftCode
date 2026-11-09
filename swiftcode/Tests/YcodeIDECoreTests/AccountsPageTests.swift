import Foundation
import Testing
import YcodeIDECore

@Suite struct AccountsPageTests {
    @Test func explanationCoversAppleAndStoredIdentities() {
        for keychain in [true, false] {
            let text = AccountsPage.explanation(keychain: keychain)
            #if os(macOS)
            #expect(text.contains("Apple Account"))
            #else
            #expect(text.contains("does not sign in to accounts"))
            #endif
            #expect(text.contains("never asks for or stores passwords"))
        }
        #expect(AccountsPage.explanation(keychain: true).contains("identities already in your keychain"))
        #expect(AccountsPage.explanation(keychain: false).contains("identities SwiftCode finds on this computer"))
        #if os(Linux)
        #expect(!AccountsPage.explanation.contains("keychain"))
        #else
        #expect(AccountsPage.explanation.contains("keychain"))
        #endif
    }

    @Test func pageTexts() {
        #expect(AccountsPage.title == "Accounts")
        #expect(AccountsPage.emptyText == "No Accounts")
        #expect(AccountsPage.sheetTitle == "Add Account")
    }

    @Test func listIsEmptyUntilKeysExist() {
        #expect(NoAppStoreConnectKeys().keys().isEmpty)
        #expect(AccountsPage.rows(from: NoAppStoreConnectKeys()).isEmpty)
    }

    @Test func keyStoreSeam() throws {
        struct OneKey: AppStoreConnectKeyStore {
            func keys() -> [AppStoreConnectAPIKey] {
                [AppStoreConnectAPIKey(keyID: "ABC123DEFG", issuerID: "00000000-0000-0000-0000-000000000000",
                                       keyFile: URL(fileURLWithPath: "/keys/AuthKey_ABC123DEFG.p8"))]
            }
        }
        #expect(AccountsPage.rows(from: OneKey()) == [AccountsPage.Row(title: "App Store Connect API Key", detail: "ABC123DEFG")])
        let key = OneKey().keys()[0]
        let decoded = try JSONDecoder().decode(AppStoreConnectAPIKey.self, from: JSONEncoder().encode(key))
        #expect(decoded == key)
    }

    @Test func paneOrder() {
        #expect(SettingsPaneOrder.all.count == 13)
        #expect(Array(SettingsPaneOrder.all.prefix(4)) == ["General", "Appearance", "Accounts", "Assist"])
        #expect(SettingsPaneOrder.all.last == "Simulators")
        #expect(SettingsPaneOrder.linux == ["General", "Appearance", "Accounts", "Assist", "Behaviors", "Navigation",
                                            "Notifications", "Editing", "Shortcuts", "Source Control", "Components", "Locations"])
    }
}
