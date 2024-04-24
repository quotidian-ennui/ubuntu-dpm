# README.md

Tries to be a thing that can 'manage' applications on an ubuntu machine. The why is because of [https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/](https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/)

It's not intended to be that useful to anyone else, but if you want to use it, you can (but don't hold me accountable; you're good enough to want to use this, you're good enough to understand bash scripts).

## TLDR

> All in all from a `wsl --install Debian|Ubuntu` or similar you should have everything ready toolwise in ~10 minutes (there's a lot of network traffic).
>
> - If you want to use your own tools.yml file then `export DPM_TOOLS_YAML=/path/to/my/tools.yml` before running `just tools`.
> - You may need to do a `wsl.exe --shutdown` dance after `bootstrap.sh baseline`. We will try to modify /etc/wsl.conf if it doesn't already exist to enable systemd (because docker wants it) and we do some shenanigans to binfmt to stop it from making wslview sad.

- `bootstrap.sh repos` to install the apt repos we need
- `bootstrap.sh baseline` to install some initial tooling
- `just init`
- `just tools` | `just install`
- `just sdk all`

## Notes

- I also do this before I start

```bash
echo "$USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/lenient
sudo apt update && sudo apt -y install vim nfs-common unison jq direnv zip unzip net-tools git rcm
# This stuff is useful, but entirely optional.
if [[ -z "$WSL_DISTRO_NAME" ]]; then
  sudo apt -y install openssh-server
fi
if [[ -z "$WSL_DISTRO_NAME" && -n "${XDG_CURRENT_DESKTOP}" ]]; then
  sudo apt -y install fonts-firacode
fi
sudo update-alternatives --set editor /usr/bin/vim.basic
sudo apt -y autoremove
if [ ! -f ~/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -a 96
fi
```

- `echo "$USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/lenient` is a terrible idea.
- `just` is installed during `bootstrap.sh baseline` via gh-release-install; it gets ovewritten again when you do `just tools`
- `yq` will be installed during `just tools` if it doesn't already exist (and promptly overwritten by the tool installation); previously we used docker, but people might not want docker all the time every time.
- Post init+tools, you probably want to do a `hash -r` to clear out the bash hash cache otherwise you get `/usr/bin/just not found` errors.
- Keeps a track of the files its installed in `~/.config/ubuntu-dpm/installed-versions` so it doesn't try to install the same version of things repeatedly.
