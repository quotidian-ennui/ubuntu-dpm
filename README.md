# README.md

Tries to be a thing that can 'manage' applications on an ubuntu machine. The why is because of [https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/](https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/)

It's not intended to be that useful to anyone else, but if you want to use it, you can (but don't hold me accountable; you're good enough to want to use this, you're good enough to understand bash scripts).

## TLDR;

> If you want to use your own tools.yml file then `export DPM_TOOLS_YAML=/path/to/my/tools.yml` before running `just tools`.

- `bootstrap.sh repos` to install the apt repos we need
- `bootstrap.sh baseline` to install some initial tooling
- `just init`
- `just tools` | `just install`
- `just sdk`

Yeah, I know, I'm a terrible person for using `just` because it's yet another thing you need to install. I'm not sorry.

## Notes

- I also do this before I start
```bash
echo "$USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/lenient
sudo apt update && sudo apt -y install vim nfs-common unison jq direnv zip unzip net-tools git
if [[ -z "$WSL_DISTRO_NAME" ]]; then
  sudo apt -y install openssh-server
fi
if [[ -z "$WSL_DISTRO_NAME" && -n "${XDG_CURRENT_DESKTOP}" ]]; then
  sudo apt -y install fonts-firacode
fi
sudo update-alternatives --set editor /usr/bin/vim.basic
sudo apt -y autoremove
if [ ! -f ~/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -a 32
fi
```
- `echo "$USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/lenient` is a terrible idea.
- If `yq` is not installed then we use it via docker as part of the tool installation; afterwards it'll exist.
- Post init+tools, you probably want to do a `hash -r` to clear out the bash hash cache otherwise you get `/usr/bin/just not found` errors.
- Keeps a track of the files its installed in `~/.config/ubuntu-dpm/installed-versions` so it doesn't try to install the same version of things repeatedly.
