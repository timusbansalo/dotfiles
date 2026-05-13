# dotfiles

My macOS terminal config. Oh My Zsh + Powerlevel10k + a curated `.zshrc`,
`.gitconfig`, and a few setup scripts.

## What's here

| File                     | Symlinks to              | Purpose                                                |
|--------------------------|--------------------------|--------------------------------------------------------|
| `.zshrc`                 | `~/.zshrc`               | shell config: OMZ, plugins, history, aliases, fns      |
| `.gitconfig`             | `~/.gitconfig`           | global git config + aliases (`git s`, `git l`, ...)    |
| `.gitignore_global`      | `~/.gitignore_global`    | files git should ignore in every repo on this Mac      |
| `install.sh`             | —                        | one-time: brew + OMZ + p10k + plugins + font + links   |
| `uninstall.sh`           | —                        | remove the symlinks (won't touch OMZ itself)           |
| `macos-defaults.sh`      | —                        | optional: keyboard, Finder, Dock, screenshot tweaks    |

## Install (on a fresh Mac)

```bash
cd ~/Downloads/Claude/dotfiles
chmod +x install.sh uninstall.sh macos-defaults.sh
./install.sh
```

Then in your terminal app's settings, **change the font to "MesloLGS NF"**
(installed automatically by the script). Open a new window — the
Powerlevel10k wizard will run on first launch.

Optionally:
```bash
./macos-defaults.sh
```

## Day-to-day

The repo lives at `~/Downloads/Claude/dotfiles/`, alongside `claude-skills`,
`claude-nvidia-projects`, and `claude-projects`. The same launchd job
(`com.subansal.claude-sync`) commits and pushes any changes to all four
repos at 6pm daily.

Edit either the symlink in `~` or the file in the repo — they're the same
inode, so it doesn't matter which.

Force a sync now: `claudesync` (alias defined in `.zshrc`).

## Customize the prompt

`p10k configure` will re-run the Powerlevel10k wizard. It writes to
`~/.p10k.zsh`. Once you like it:

```bash
cp ~/.p10k.zsh ~/Downloads/Claude/dotfiles/.p10k.zsh
~/Downloads/Claude/dotfiles/install.sh   # re-link so the file is canonical
```

The next auto-sync at 6pm pushes it to GitHub.

## Uninstall

```bash
~/Downloads/Claude/dotfiles/uninstall.sh   # removes symlinks
uninstall_oh_my_zsh                        # removes OMZ (optional, in a new shell)
```

Backups of replaced files live at `~/.dotfiles-backup-<timestamp>/`.
