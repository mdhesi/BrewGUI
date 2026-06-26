# Releasing BrewGUI

How to cut a signed, notarized release that users can install with
`brew install --cask mdhesi/tap/brewgui` or a downloaded `.dmg`.

The heavy lifting is in [`scripts/release.sh`](scripts/release.sh) — it archives,
exports with your Developer ID, builds a DMG, notarizes it, and staples the
ticket. The parts only **you** can do are the one-time credential setup and the
final upload + tap update.

---

## Prerequisites (one time)

1. **Apple Developer Program membership** ($99/yr). Notarization is not possible
   without it.

2. **A "Developer ID Application" certificate** in your login keychain. In Xcode:
   *Settings → Accounts → (your team) → Manage Certificates → +
   → Developer ID Application*.

3. **Your Team ID** (10 characters, on the Apple Developer *Membership* page).
   Put it in [`scripts/ExportOptions.plist`](scripts/ExportOptions.plist),
   replacing `REPLACE_TEAM_ID`.

4. **Hardened Runtime enabled.** In Xcode → target *BrewGUI* → *Signing &
   Capabilities*: set your Team, and add the **Hardened Runtime** capability if
   it isn't there. Notarization rejects apps without it.

5. **A stored notary credential profile** so the script can submit without
   prompting. Create it once with an
   [app-specific password](https://support.apple.com/en-us/102654):

   ```sh
   xcrun notarytool store-credentials brewgui-notary \
     --apple-id "you@example.com" \
     --team-id "YOUR_TEAM_ID" \
     --password "app-specific-password"
   ```

   (The name `brewgui-notary` matches `NOTARY_PROFILE` in the script.)

6. **A tap repo.** Create a GitHub repo named **`homebrew-tap`** under your
   account — that makes the tap `mdhesi/tap`. Copy
   [`scripts/brewgui.rb`](scripts/brewgui.rb) into it at `Casks/brewgui.rb`.

---

## Cutting a release

1. **Bump the version.** In Xcode → target → *General*, set the *Version* (e.g.
   `1.0.0`). This is `MARKETING_VERSION`; the script reads it automatically.

2. **Build + notarize.**

   ```sh
   ./scripts/release.sh
   # or pin the version: VERSION=1.0.0 ./scripts/release.sh
   ```

   On success it prints the DMG path, the version, and the **sha256** — keep that
   sha256 for the next step.

3. **Create the GitHub Release.** Tag it `v1.0.0` and upload `build/BrewGUI-1.0.0.dmg`
   as a release asset:

   ```sh
   gh release create v1.0.0 build/BrewGUI-1.0.0.dmg \
     --title "BrewGUI 1.0.0" --notes "First release."
   ```

4. **Update the cask** in your `homebrew-tap` repo (`Casks/brewgui.rb`): set
   `version` and paste the `sha256` from step 2. Commit and push.

5. **Verify the install path:**

   ```sh
   brew install --cask mdhesi/tap/brewgui
   ```

6. **Update the landing page.** In `docs/index.html`, the install command and
   download button are already wired to `mdhesi/tap/brewgui` and the Releases
   page — just confirm they match once the release is live.

---

## Sanity checks

```sh
# App is properly signed (Developer ID) and notarized:
codesign --verify --deep --strict --verbose=2 build/export/BrewGUI.app
spctl -a -t exec -vvv build/export/BrewGUI.app        # should say "accepted ... Notarized Developer ID"
xcrun stapler validate build/BrewGUI-1.0.0.dmg
```

## Troubleshooting

- **Notarization "Invalid" status** — run
  `xcrun notarytool log <submission-id> --keychain-profile brewgui-notary` to see
  exactly which file/signature was rejected (usually a missing hardened runtime
  or an unsigned bundled binary).
- **`spctl` rejects the app** — it wasn't stapled, or a nested binary isn't
  signed. Re-run the script; it staples after notarizing.
- **"No Developer ID Application certificate found"** — see prerequisite #2.
