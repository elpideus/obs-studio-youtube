# Maintaining

## New Arch obs-studio release

```sh
tools/update-from-arch.py            # newest Arch tag, or: tools/update-from-arch.py 32.2.3-1
git diff -- obs-studio-youtube       # review what Arch changed
cd obs-studio-youtube && makepkg -f  # test build (needs your credentials.env)
```

- Every edit the generator makes is anchored on exact text. If Arch restructures the PKGBUILD, the script stops with "anchor … found N times"; adapt `transform()` in `tools/update-from-arch.py`.
- `.arch-tag` records which Arch tag the committed PKGBUILD came from. `pkgver-pkgrel` mirrors that tag.
- Since 33.0.0 Arch builds one package with the browser plugin inside. `obs-studio-youtube` replaces our old `obs-studio-youtube-plugin-browser`, whose exact dependency on `obs-studio-youtube=32.2.2-1` would otherwise block the update.
- Commit, then push to the AUR (below).

## New obs-vkcapture release

The Capture Audio feature lives in the fork <https://github.com/elpideus/obs-vkcapture>, branch `capture-audio`: four commits on top of an upstream tag.

```sh
cd obs-vkcapture                       # your clone of the fork
git fetch upstream --tags
git rebase --onto v1.5.7 v1.5.6 capture-audio
cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build   # must build cleanly
git tag -s v1.5.7-audio1 -m "obs-vkcapture 1.5.7 with Capture Audio (1)"
git push --force-with-lease origin capture-audio && git push origin v1.5.7-audio1
```

Then in `obs-vkcapture-audio/PKGBUILD`, set `pkgver=1.5.7`, `_audiorel=1` and `pkgrel=1`. Update `sha256sums` with `makepkg -g`, then run `makepkg --printsrcinfo > .SRCINFO`.

For a fix to the audio feature without a new upstream version, bump `_audiorel` and `pkgrel`.

The fork still installs to `/usr/lib/obs-plugins`. OBS 33 loads that folder as "legacy" and says it will stop in a future update, when the fork's `CMakeLists.txt` has to move to `/usr/lib/obs-modules/plugins` and `/usr/share/obs/obs-modules/plugins`.

## Publishing to the AUR

Each package base is its own AUR git repository: `obs-studio-youtube` and `obs-vkcapture-audio`. Only `PKGBUILD`, `.SRCINFO` and the files listed in `source=()` belong there.

```sh
git clone ssh://aur@aur.archlinux.org/obs-studio-youtube.git /tmp/aur-obs
git -C /tmp/aur-obs rm -q --ignore-unmatch '*.patch'
cp obs-studio-youtube/* obs-studio-youtube/.SRCINFO /tmp/aur-obs/
cd /tmp/aur-obs && git add -A && git commit -m "Update to 33.0.0-1" && git push
```

This needs an AUR account with your SSH public key added. Never put a Google client ID or secret into the AUR, the repo or a PKGBUILD.
