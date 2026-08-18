#!/bin/bash
# Bouwt Klaverjas voor de Mac en maakt er een schijfkopie van om weg te geven.
#
#   ./maak-uitgave.sh [versie]
#
# Ondertekent met een Developer ID als die in de sleutelhanger zit, en biedt de
# app dan ook ter waarmerking aan bij Apple als er een notarytool-profiel is.
# Ontbreekt een van beide, dan wordt er ad-hoc ondertekend: het spel werkt, maar
# de ontvanger moet de eerste keer met de rechtermuisknop openen.
set -e

VERSIE="${1:-1.0}"
HIER="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$HIER/../Klaverjas/Klaverjas.xcodeproj"
WERK="$(mktemp -d)"
trap 'rm -rf "$WERK"' EXIT

echo "== bouwen (universeel: Apple Silicon en Intel)"
xcodebuild -project "$PROJECT" -scheme Klaverjas -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$WERK/dd" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build >/dev/null

APP="$WERK/dd/Build/Products/Release/Klaverjas.app"
[ -d "$APP" ] || { echo "geen app gebouwd"; exit 1; }
echo "   architecturen: $(lipo -archs "$APP/Contents/MacOS/Klaverjas")"

echo "== ondertekenen"
ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 |
     sed -E 's/.*"(.*)"/\1/')
if [ -n "$ID" ]; then
  echo "   met: $ID"
  codesign --force --options runtime --timestamp --sign "$ID" "$APP"
  ONDERTEKEND=echt
else
  echo "   geen Developer ID gevonden; ad-hoc"
  codesign --force --options runtime --sign - "$APP"
  ONDERTEKEND=adhoc
fi
codesign --verify --strict "$APP"

echo "== schijfkopie maken"
MAP="$WERK/dmg"
mkdir -p "$MAP"
cp -R "$APP" "$MAP/"
ln -s /Applications "$MAP/Programma's"
cp "$HIER/Lees mij.txt" "$MAP/" 2>/dev/null || true
DMG="$HIER/Klaverjas-$VERSIE.dmg"
rm -f "$DMG"
hdiutil create -volname "Klaverjas" -srcfolder "$MAP" -ov -format UDZO "$DMG" >/dev/null
echo "   $DMG"

if [ "$ONDERTEKEND" = echt ] && xcrun notarytool history --keychain-profile "notary" >/dev/null 2>&1; then
  echo "== aanbieden ter waarmerking bij Apple (dit duurt een paar minuten)"
  xcrun notarytool submit "$DMG" --keychain-profile "notary" --wait
  xcrun stapler staple "$DMG"
  echo "   gewaarmerkt en geniet"
else
  echo "== niet gewaarmerkt"
  echo "   De ontvanger moet de eerste keer rechtsklikken en Openen kiezen."
fi

echo
echo "klaar: $(ls -lh "$DMG" | awk '{print $5}')  $DMG"
spctl --assess --type open --context context:primary-signature "$DMG" 2>&1 | sed 's/^/   /' || true
