# Portable starter environment

A small macOS or Debian/Ubuntu shell environment: Git, zsh, fzf, Oh My Zsh,
autosuggestions, completions, syntax highlighting and Powerlevel10k. macOS also
installs iTerm2 and a Meslo Nerd Font. On Linux, choose/install a Nerd Font in your
terminal if the prompt symbols do not display correctly.

## Back up this machine

```sh
/path/to/dotfiles/backup.sh
```

This saves original shell startup files, prompt settings and Git configuration in
`backups/<timestamp>/home/`, and iTerm2 preferences on macOS. These local snapshots
are private (directory mode 700), ignored by Git, and never pushed. Keep them on a
separate backup drive if you need disaster recovery. Symlinked settings are backed up as regular
files containing their target contents. Setup replaces a settings symlink with a
regular file without modifying the original link target. A snapshot is a settings backup, not a
complete system or package rollback.

Deployment settings refreshed in the repo:

- Platform-specific `.p10k.zsh` and iTerm2 preferences.
- `common/.zshrc.portable`, copied from the identically named home file if present.
- `common/gitconfig`: Git identity and a small allowlist of Git preferences.

Raw `.zshrc`, `.zprofile`, `.zshenv`, `.bash_profile`, `.bashrc` and `.gitconfig`
are saved locally, **not exported wholesale**. This keeps credentials and absolute
machine paths out of the starter environment. Move useful aliases and portable
settings from your old `.zshrc` into `~/.zshrc.portable` yourself; do not put secrets
there. Flutter, Android, SDK paths and private environment variables belong in
`~/.zshrc.local`, which is never deployed or pushed.

Optional full installed package inventory:

```sh
/path/to/dotfiles/backup.sh --packages
```

This uses `brew bundle dump` and writes `<platform>/packages.Brewfile` atomically.
It never overwrites the small starter Brewfile. The original macOS package list
is preserved in `macos/packages.Brewfile`; refresh it to reflect current installs.
Package snapshots are inventories, not exact version locks. Linux apt package
inventories and language environments are outside the backup scope.

To commit and push the portable settings to the configured Git remote:

```sh
/path/to/dotfiles/backup.sh --publish
```

Review portable additions, Git identity and iTerm2 preferences before publishing,
particularly if your remote is public. iTerm2 preferences may contain hostnames,
paths or custom commands. Publishing includes only the shared/platform settings
paths; unrelated staged changes stay staged. The remote, Git identity and
credentials must already be configured. An unchanged backup still retries push.

## Deploy on another machine

Clone or copy this repository, then run:

```sh
cd dotfiles
./setup.sh --dry-run
./setup.sh
```

Setup saves the target's existing settings before making changes. It installs
only starter packages by default. Optional SDKs and the full package inventory
are not installed. Existing `~/.zshrc.local` is left in place. Current portable
additions are overwritten only if a saved portable-additions file exists.
On macOS, quit iTerm2 before importing preferences; run setup from another terminal,
then open iTerm2. Preferences are platform-specific and are not imported on Linux.
Any custom commands or paths in old iTerm2 profiles may need adjustment.

To make zsh your permanent login shell:

```sh
./setup.sh --set-default-shell
```

Without that option, start the new shell with `exec zsh -l`. Setup never closes
your terminal or forces a shell reload. To deploy settings without installations,
use `./setup.sh --settings-only`. Existing `.zprofile` and `.zshenv` are left in
place, so inspect them if they override the newly deployed starter shell.

To deliberately install a full inventory (requires access to App Store purchases
and any private package sources listed in it):

```sh
./setup.sh --packages macos/packages.Brewfile
```

## Update

```sh
./autoupdate.sh
# Optional inventory and remote backup before upgrading:
./autoupdate.sh --packages --publish
```

Always backs up first, then updates installed Homebrew packages and Oh My Zsh/plugin
repositories; Debian/Ubuntu also runs apt upgrades. Update failures are reported
with a nonzero exit status. It does not update arbitrary project repositories,
macOS itself, or create a recurring schedule. No automatic apt removal is performed.

## Recover previous settings

Choose a snapshot under `backups/`, inspect `purpose.txt`, and copy the desired
files from its `home/` directory back to your home directory. To restore saved
macOS terminal preferences, quit iTerm2 and run:

```sh
defaults import com.googlecode.iterm2 /path/to/snapshot/iterm2.plist
```

Every setup and backup creates a distinct snapshot; older ones are never replaced.
Backup/export and publish are explicit actions. This repository does not back up
SSH keys, credentials, documents, projects, shell history or complete app data.

## Verification

Run `python3 tests/test_workflows.py` to check backup, publication and deployment
with isolated homes and mocked installers. No real installs, upgrades or pushes
are performed. The checks require Bash, Git and zsh.
