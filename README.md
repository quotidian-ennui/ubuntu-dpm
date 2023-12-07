# README.md

Tries to be a thing that can 'manage' applications on an ubuntu machine. The why is because of [https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/](https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/)

It's not intended to be that useful to anyone else, but if you want to use it, you can (but don't hold me accountable; you're good enough to want to use this, you're good enough to understand bash scripts).

## TLDR;

- `bootstrap.sh` to bootstrap extra apt repos and install some initial tooling
- `just init`
- `just install`

Yeah, I know, I'm a terrible person for using `just` because it's yet another thing you need to install. I'm not sorry.

## Notes

- Installs `yq` via snap as part of the `init` recipe; which is subsequently removed by the `install` recipe. Since snap may require systemd to be running the `etc/wsl.conf` in your linux distro has to enable systemd and you have to do the appropriate `wsl --shutdown` dance.
```
[boot]
systemd=true
```
- Post init+install, you probably want to do a `hash -r` to clear out the bash hash cache otherwise you get `/usr/bin/just not found` errors.