# Releasing BrewGUI

BrewGUI is distributed by **downloading it from GitHub Releases** — no Homebrew
tap, no App Store. There are two ways to cut a release:

- **Unsigned zip** ([`scripts/package.sh`](scripts/package.sh)) — needs nothing
  but Xcode. Users open it the first time via *Open Anyway*. This is the default.
- **Notarized DMG** ([`scripts/release.sh`](scripts/release.sh)) — smoother for
  users (no Gatekeeper warning), but requires an Apple Developer account.

---

## Default: unsigned zip (no Apple account)

1. **Set the version.** Xcode → target *BrewGUI* → *General* → *Version* (e.g.
   `1.0.0`). The scripts read this automatically.

2. **Build + zip:**

   ```sh
   ./scripts/package.sh
   ```

   Produces `build/BrewGUI-<version>.zip`.

3. **Publish the release:**

   ```sh
   gh release create v1.0.0 build/BrewGUI-1.0.0.zip \
     --title "BrewGUI 1.0.0" --notes "First release."
   ```

That's it — the README and landing page already point users at the Releases page
and explain the first-launch *Open Anyway* step.

### What users see (unsigned)

Because the app isn't notarized, the first launch is blocked by Gatekeeper. Users:
open it, then **System Settings → Privacy & Security → Open Anyway**. If macOS
still refuses, `xattr -dr com.apple.quarantine /Applications/BrewGUI.app`. The
README documents this.

---

## Optional: notarized DMG (smoother, needs Apple Developer account)

If you want to remove the Gatekeeper friction entirely, notarize.

**One-time setup:**

1. **Apple Developer Program** membership ($99/yr).
2. A **Developer ID Application** certificate (Xcode → *Settings → Accounts →
   Manage Certificates → + → Developer ID Application*).
3. Put your 10-char **Team ID** in
   [`scripts/ExportOptions.plist`](scripts/ExportOptions.plist).
4. Enable **Hardened Runtime** on the target (*Signing & Capabilities*).
5. Store a notary credential profile (uses an
   [app-specific password](https://support.apple.com/en-us/102654)):

   ```sh
   xcrun notarytool store-credentials brewgui-notary \
     --apple-id "you@example.com" --team-id "YOUR_TEAM_ID" \
     --password "app-specific-password"
   ```

**Each release:**

```sh
./scripts/release.sh
# archives -> Developer ID export -> DMG -> notarize -> staple, prints the sha256
gh release create v1.0.0 build/BrewGUI-1.0.0.dmg --title "BrewGUI 1.0.0" --notes "…"
```

**Verify:**

```sh
spctl -a -t exec -vvv build/export/BrewGUI.app   # -> "accepted ... Notarized Developer ID"
xcrun stapler validate build/BrewGUI-1.0.0.dmg
```

**Troubleshooting:** if notarization comes back *Invalid*, run
`xcrun notarytool log <submission-id> --keychain-profile brewgui-notary` for the
exact rejection (usually missing hardened runtime or an unsigned nested binary).
