# Homebrew cask template for BrewGUI.
#
# This file belongs in your TAP repo, not this one. Create a repo named
# `homebrew-tap` (so the tap is `mdhesi/tap`) and place this at:
#   mdhesi/homebrew-tap/Casks/brewgui.rb
#
# After each release, update `version` and `sha256` (the release script prints
# the sha256). See RELEASING.md.

cask "brewgui" do
  version "1.0.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/mdhesi/BrewGUI/releases/download/v#{version}/BrewGUI-#{version}.dmg"
  name "BrewGUI"
  desc "Native macOS GUI for Homebrew"
  homepage "https://github.com/mdhesi/BrewGUI"

  depends_on macos: ">= :sonoma"

  app "BrewGUI.app"

  zap trash: [
    "~/Library/Application Support/BrewGUI",
  ]
end
