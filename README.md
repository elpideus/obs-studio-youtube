# obs-studio-youtube

OBS Studio for Arch Linux and derivatives (CachyOS, EndeavourOS, …) with:

- **YouTube account integration**: Connect Account, Manage Broadcast (pick one of your scheduled broadcasts or create one), and the live chat dock. Distribution builds can't offer this because it needs a Google OAuth client compiled in. Here it is built with **your own** client.
- **Game Capture audio**: a fork of [obs-vkcapture](https://github.com/nowrep/obs-vkcapture) whose Game Capture source has a **Capture Audio** option, like on Windows. It records the PipeWire audio of the captured game's process, and nothing else.
- **Automatic rebuilds** when your repositories update `obs-studio`.

Website: <https://elpideus.github.io/obs-studio-youtube/> · Privacy policy: <https://elpideus.github.io/obs-studio-youtube/privacy.html>

The OBS source is **unmodified upstream**, built with the same options and patches as Arch Linux's `obs-studio` package. The only differences are the YouTube build options and the package names.

| Package | Replaces | What |
|---|---|---|
| `obs-studio-youtube` | `obs-studio` | OBS Studio + YouTube integration |
| `obs-studio-youtube-plugin-browser` | `obs-studio-plugin-browser` | Browser source/docks (needed for the chat dock) |
| `obs-vkcapture-audio` | `obs-vkcapture` | Game Capture with Capture Audio ([fork](https://github.com/elpideus/obs-vkcapture), branch `capture-audio`) |
| `lib32-obs-vkcapture-audio` | `lib32-obs-vkcapture` | Its 32-bit Vulkan/OpenGL layer |

## Install

```sh
git clone https://github.com/elpideus/obs-studio-youtube.git
cd obs-studio-youtube
./install.sh
```

The installer:
1. asks for your Google OAuth client the first time (see below) and saves it to `~/.config/obs-youtube/credentials.env` (mode 600);
2. builds `obs-studio-youtube` for **exactly the `obs-studio` version your repos carry**, regenerating the PKGBUILD from Arch's matching packaging tag;
3. installs it with pacman, which asks before replacing `obs-studio`;
4. builds and installs `obs-vkcapture-audio` (needs `[multilib]`);
5. enables `obs-youtube-update` (see [Updates](#updates)).

Options: `--no-vkcapture`, `--no-browser`, `--no-auto-update`, `--new-credentials`. Keep the cloned folder: the update helper runs from it.

Manual build: `cd obs-studio-youtube && makepkg -si` (and the same in `obs-vkcapture-audio/`). The YouTube build reads your client from `~/.config/obs-youtube/credentials.env`, or from `OBS_YOUTUBE_CLIENTID` / `OBS_YOUTUBE_SECRET`. Point `OBS_YOUTUBE_CREDENTIALS` at another file if needed. Clean-chroot builds must pass the environment variables in.

## Google API client

The YouTube login uses a Google OAuth client that **you** own. It's free and takes about 5 minutes. Your client ID and secret end up compiled into your local OBS. Don't share them or commit them anywhere.

1. Open <https://console.cloud.google.com> and **create a project** (any name).
2. **APIs & Services → Library**: search for **YouTube Data API v3** and click **Enable**.
3. **Google Auth Platform → Branding**:
   - App name: anything, e.g. "My OBS". Only you see it.
   - User support email and developer contact email: yours.
   - Application home page: `https://elpideus.github.io/obs-studio-youtube/`. Privacy policy: `https://elpideus.github.io/obs-studio-youtube/privacy.html`. Authorized domain: `elpideus.github.io`. You can use your own pages instead.
   - **Don't upload a logo.** A logo makes Google's app verification mandatory.
4. **Audience**: user type **External**, then **Publish app** so the status is **In production**.
   - In "Testing", only listed test users can sign in (others get *"Access blocked … Error 403: access_denied"*), and the login expires every 7 days.
5. **Clients → Create client**: application type **Desktop app**. Copy the **Client ID** and **Client secret**.
6. Run `./install.sh` and paste them when asked.

In OBS: **Settings → Stream**, service **YouTube - RTMPS**, **Connect Account**. Your browser opens. Google shows **"Google hasn't verified this app"**, because it's your own unverified app: click **Advanced → Go to … (unsafe)** and allow access. OBS stores the login per profile.

Limits of an unverified personal app: at most 100 users, which is irrelevant for one person, and 10,000 YouTube API units per day, which is plenty for setting up broadcasts.

## Game Capture audio

Add a **Game Capture (Vulkan/OpenGL)** source and tick **Capture Audio**. Start games through the capture layer:
- **Steam:** set the launch options to `obs-gamecapture %command%`;
- **other launchers:** set `OBS_VKCAPTURE=1`;
- start OBS before the game.

How it works: vkcapture knows the PID of the game that connected (`SO_PEERCRED`). The fork links every PipeWire playback stream with that `application.process.id` into a private capture node. This also works for Proton games. If the PID doesn't match, for example for a game running in its own PID namespace, it matches by executable name instead.

## Updates

Because these packages replace `obs-studio`, `pacman -Syu` no longer updates OBS. `obs-youtube-update` takes over:
- **When it runs:** a user timer runs it daily, and a path unit runs it after every pacman transaction.
- **What it checks:** whether your repos have a newer `obs-studio`, either a new OBS release or a rebuild after a library update such as ffmpeg.
- **What it does then:** it regenerates the PKGBUILD from Arch's matching tag and builds it in the background at low priority. Then it notifies you to install:

```sh
obs-youtube-update --install   # asks for your password
obs-youtube-update --status    # versions and pending builds
```

Until you install the update, the current OBS keeps working.

New **obs-vkcapture** releases need the fork rebased (see [MAINTAINING.md](MAINTAINING.md)). The helper notifies you when one is out.

## Uninstall

Go back to the repo packages; pacman offers to replace them:

```sh
sudo pacman -S obs-studio obs-studio-plugin-browser obs-vkcapture lib32-obs-vkcapture
systemctl --user disable --now obs-youtube-update.timer obs-youtube-update.path
rm ~/.local/bin/obs-youtube-update ~/.config/systemd/user/obs-youtube-update.*
```

Then delete `~/.config/obs-youtube/` and the Google Cloud project if you no longer need them.

## Credits and licenses

- **OBS Studio:** © the OBS Project, GPL-2.0.
- **PKGBUILD:** generated from Arch Linux's `obs-studio` packaging (0BSD) by `tools/update-from-arch.py`. The two `obs-browser-*.patch` files come from Arch's packaging (upstream obs-browser pull requests).
- **obs-vkcapture:** © David Rosca, GPL-2.0-or-later. The fork's PipeWire code is adapted from [obs-pipewire-audio-capture](https://github.com/dimtpap/obs-pipewire-audio-capture) © Dimitris Papaioannou, GPL-2.0-or-later.
- **This repository's own files** (scripts, PKGBUILD changes, website): [0BSD](LICENSE).

Unofficial and not affiliated with or endorsed by the OBS Project or Google.
