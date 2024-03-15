# README.md

Tries to be a thing that can 'manage' applications on an ubuntu machine. The why is because of [https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/](https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/)

It's not intended to be that useful to anyone else, but if you want to use it, you can (but don't hold me accountable; you're good enough to want to use this, you're good enough to understand bash scripts).

## TLDR;

- `bootstrap.sh repos` to install the apt repos we need
- `bootstrap.sh baseline` to install some initial tooling
- `just init`
- `just tools` | `just install`
- `just sdk`

Yeah, I know, I'm a terrible person for using `just` because it's yet another thing you need to install. I'm not sorry.

## Notes

- `echo "$USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers` (or into `/etc/sudoers.d/i_hates_security`). This is for _convenience reasons_; it's a terrible idea.
- Installs `yq` via snap as part of the `init` recipe; which is subsequently removed by the `install` recipe. Since snap may require systemd to be running the `etc/wsl.conf` in your WSL2 linux distro has to enable systemd and you have to do the appropriate `wsl --shutdown` dance. This may already be true if you're building a new machine (as I did in 2023-12; but YMMV).
```
[boot]
systemd=true
```
- Post init+tools, you probably want to do a `hash -r` to clear out the bash hash cache otherwise you get `/usr/bin/just not found` errors.
- Keeps a track of the files its installed in `~/.config/ubuntu-dpm/installed-versions` so it doesn't try to install the same version of things repeatedly.
