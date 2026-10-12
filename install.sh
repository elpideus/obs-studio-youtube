#!/bin/bash
# install.sh - build and install, on Arch Linux and derivatives (CachyOS, EndeavourOS, ...):
#   obs-studio-youtube (+ -plugin-browser)  OBS Studio with the YouTube account integration,
#                                           built with your own Google OAuth client
#   obs-vkcapture-audio (+ lib32-)          Game Capture with a "Capture Audio" option
#   obs-youtube-update                      rebuilds OBS when the repos update obs-studio
# They replace obs-studio, obs-studio-plugin-browser, obs-vkcapture and lib32-obs-vkcapture;
# pacman asks before removing those.
#
# Usage: ./install.sh [--no-vkcapture] [--no-browser] [--no-auto-update] [--new-credentials]
set -euo pipefail

REPO=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/obs-youtube"
CRED="$CONF_DIR/credentials.env"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/obs-studio-youtube"

want_vk=true want_browser=true want_update=true new_cred=false
for a in "$@"; do
	case $a in
		--no-vkcapture) want_vk=false ;;
		--no-browser) want_browser=false ;;
		--no-auto-update) want_update=false ;;
		--new-credentials) new_cred=true ;;
		-h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "unknown option: $a" >&2; exit 2 ;;
	esac
done

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "run this as your normal user; it uses sudo only for pacman"
command -v pacman >/dev/null && command -v makepkg >/dev/null || die "this installer is for Arch Linux and derivatives"
pacman -Q base-devel git >/dev/null 2>&1 || { say "Installing base-devel and git"; sudo pacman -S --needed base-devel git; }

# --- 1. Google OAuth client ---------------------------------------------------------------
cred_ok() {
	grep -qE '^YOUTUBE_CLIENTID="[0-9A-Za-z_-]+\.apps\.googleusercontent\.com"$' "$CRED" 2>/dev/null &&
		grep -qE '^YOUTUBE_SECRET="[0-9A-Za-z_-]+"$' "$CRED" 2>/dev/null
}
if $new_cred || ! cred_ok; then
	say "The YouTube login needs your own Google OAuth client (free, about 5 minutes)"
	cat <<'EOF'
    1. https://console.cloud.google.com : create a project.
    2. APIs & Services > Library > "YouTube Data API v3" > Enable.
    3. Google Auth Platform > Branding: app name, your email, home page and privacy policy
       URL (you may use https://elpideus.github.io/obs-studio-youtube/ and
       https://elpideus.github.io/obs-studio-youtube/privacy.html with the authorized domain
       elpideus.github.io). Do NOT upload a logo (that forces Google's verification).
    4. Audience: External, then "Publish app" (In production). In "Testing" the login
       expires every 7 days and only listed test users can sign in.
    5. Clients > Create client > Application type "Desktop app".
    Full guide: https://github.com/elpideus/obs-studio-youtube#google-api-client
EOF
	read -rp "    Client ID: " cid
	read -rsp "    Client secret (input hidden): " csec; echo
	[[ $cid =~ ^[0-9A-Za-z_-]+\.apps\.googleusercontent\.com$ ]] || die "that doesn't look like a client ID (…apps.googleusercontent.com)"
	[[ $csec =~ ^[0-9A-Za-z_-]+$ ]] || die "that doesn't look like a client secret"
	(umask 077; mkdir -p "$CONF_DIR"; printf 'YOUTUBE_CLIENTID="%s"\nYOUTUBE_SECRET="%s"\n' "$cid" "$csec" >"$CRED")
	note "Saved to $CRED (readable only by you). Never share it."
fi

# --- helpers --------------------------------------------------------------------------------
missing_deps() {  # <pkgdir>: build/run dependencies not installed yet (obs-studio itself excluded)
	(cd "$1" && makepkg --printsrcinfo) | awk '/^\t(make)?depends = /{print $3}' |
		grep -v '^obs-studio' | xargs -r pacman -T || true
}
install_deps() {
	local missing; missing=$(missing_deps "$1")
	[[ -z $missing ]] && return 0
	say "Installing build dependencies: $(echo $missing)"
	# Installed explicitly (not --asdeps) so orphan cleanup can't remove them; obs-youtube-update
	# needs them for the automatic rebuilds.
	sudo pacman -S --needed $missing
}
build() {  # <pkgdir> <name>: build into $CACHE/pkg/<name>, print the package files
	local out="$CACHE/pkg/$2"
	rm -rf "$out"; mkdir -p "$out" "$CACHE/sources" "$CACHE/build"
	(cd "$1" && BUILDDIR="$CACHE/build" PKGDEST="$out" SRCDEST="$CACHE/sources" makepkg -f --nocheck --noconfirm) >&2
	find "$out" -name '*.pkg.tar.*' ! -name '*.sig' | sort
}

# --- 2. OBS Studio with YouTube -------------------------------------------------------------
say "Preparing obs-studio-youtube"
repo_ver=$(pacman -Si obs-studio 2>/dev/null | awk '/^Version/{print $3; exit}')
work="$REPO/obs-studio-youtube"
if [[ -n $repo_ver ]]; then
	tag="${repo_ver%-*}-$(cut -d. -f1 <<<"${repo_ver##*-}")"
	gen="$CACHE/auto/$tag"
	if python3 -I "$REPO/tools/update-from-arch.py" "$tag" --cache "$CACHE/arch-obs-studio" --out "$gen" >/dev/null 2>&1; then
		work=$gen
		note "Matching your repos' obs-studio $repo_ver (Arch packaging tag $tag)"
	else
		note "No Arch packaging tag $tag; using the PKGBUILD in this repo ($(cat "$REPO/obs-studio-youtube/.arch-tag"))"
	fi
fi
install_deps "$work"
say "Building OBS Studio (takes a few minutes)"
mapfile -t obs_pkgs < <(build "$work" obs-studio-youtube)
rm -rf "$CACHE/build/obs-studio-youtube"  # its CMakeCache.txt contains your client secret
[[ ${#obs_pkgs[@]} -gt 0 ]] || die "building obs-studio-youtube failed (see the output above)"
$want_browser || mapfile -t obs_pkgs < <(printf '%s\n' "${obs_pkgs[@]}" | grep -v -- '-plugin-browser-')
say "Installing (pacman will offer to replace obs-studio; answer y)"
sudo pacman -U --needed "${obs_pkgs[@]}"

# --- 3. Game Capture with Capture Audio -----------------------------------------------------
if $want_vk; then
	if pacman -Si lib32-glibc >/dev/null 2>&1; then
		say "Building obs-vkcapture-audio"
		install_deps "$REPO/obs-vkcapture-audio"
		mapfile -t vk_pkgs < <(build "$REPO/obs-vkcapture-audio" obs-vkcapture-audio)
		[[ ${#vk_pkgs[@]} -gt 0 ]] || die "building obs-vkcapture-audio failed (see the output above)"
		say "Installing (pacman will offer to replace obs-vkcapture; answer y)"
		sudo pacman -U --needed "${vk_pkgs[@]}"
	else
		note "Skipping obs-vkcapture-audio: it needs the [multilib] repo for its 32-bit layer."
	fi
fi

# --- 4. Automatic rebuilds ------------------------------------------------------------------
if $want_update; then
	say "Enabling obs-youtube-update (rebuilds OBS after repo updates, then notifies you)"
	mkdir -p "$HOME/.local/bin" "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
	ln -sfn "$REPO/tools/obs-youtube-update" "$HOME/.local/bin/obs-youtube-update"
	cp "$REPO"/systemd/obs-youtube-update.{service,timer,path} "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/"
	systemctl --user daemon-reload
	systemctl --user enable --now obs-youtube-update.timer obs-youtube-update.path
	note "Keep this folder ($REPO): the helper runs from it."
fi

say "Done. In OBS: Settings > Stream > Service \"YouTube - RTMPS\" > Connect Account."
note "Google will say \"Google hasn't verified this app\": that's your own app; click Advanced > Go to ..."
note "Game Capture: launch games with  obs-gamecapture %command%  and tick \"Capture Audio\"."
