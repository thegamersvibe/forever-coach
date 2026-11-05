#!/usr/bin/env bash
# Usage: scripts/release.sh 1.0.1   (run from repo root; needs go, gh, python3)
set -euo pipefail
V=${1:?version}
sed -i "s/^## Version: .*/## Version: $V/" addon/ForeverCoach/ForeverCoach.toc
sed -i "s/^FC.VERSION = .*/FC.VERSION = \"$V\"/" addon/ForeverCoach/Core.lua
sed -i "s/^const Version = .*/const Version = \"$V\"/" desktop/main.go
IFS=. read -r MA MI PA <<< "$V"
python3 - "$V" "$MA" "$MI" "$PA" <<'PY'
import json,sys
v,ma,mi,pa=sys.argv[1],*map(int,sys.argv[2:])
p='desktop/versioninfo.json'; d=json.load(open(p))
for k in ('FileVersion','ProductVersion'): d['FixedFileInfo'][k]={'Major':ma,'Minor':mi,'Patch':pa,'Build':0}; d['StringFileInfo'][k]=v
json.dump(d,open(p,'w'),indent=2)
PY
(cd desktop && "$(go env GOPATH)/bin/goversioninfo" -64 -o resource_windows_amd64.syso versioninfo.json)
python3 scripts/build_rules_lua.py
(cd desktop && go test ./... && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags "-H windowsgui" -o ../dist/ForeverCoach.exe .)
rm -rf dist/pkg && mkdir -p dist/pkg && cp -r addon/ForeverCoach dist/pkg/ && cp dist/ForeverCoach.exe README.md dist/pkg/
(cd dist/pkg && python3 -c "import shutil; shutil.make_archive('../ForeverCoach-$V', 'zip', '.')")
(cd dist && sha256sum "ForeverCoach-$V.zip" ForeverCoach.exe > SHA256SUMS.txt)
git add -A && git commit -qm "Release v$V" || true
git tag -f "v$V" && git push -q origin main && git push -q -f origin "v$V"
gh release create "v$V" "dist/ForeverCoach-$V.zip" dist/ForeverCoach.exe dist/SHA256SUMS.txt --title "Forever Coach v$V" --generate-notes
