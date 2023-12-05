# README.md

Tries to be a thing that can 'manage' applications on an ubuntu machine. The why is because of [https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/](https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/)

It's not intended to be that useful to anyone else, but if you want to use it, you can (but don't hold me accountable; you're good enough to want to use this, you're good enough to understand bash scripts).

## TLDR;

- `bootstrap.sh` to bootstrap extra apt repos and install some initial tooling
- `just init`
- `just install`

Yeah, I know, I'm a terrible person for using `just` because it's yet another thing you need to install. I'm not sorry.

## Notes

The keen-eyed will have seen that I'm installing `yq` via python+pip and also `mikefarah/yq` via dpm. I suppose I could install `mikefarah/yq` via snap, and then uninstall it in the same way that I'm uninstalling `just`.

I have `mikefarah/yq` because I can do this `yq eval-all '. as $item ireduce ({}; . *+ $item )' "gh-aliases-old.yml" "gh-aliases-new.yml" > "gh-aliases.yml"` to merge my github aliases files together. I have this exported as a bash-function for me to use in scripts :

```
function findYQ() {
  if builtin type -P myq >/dev/null 2>&1; then
    echo "myq"
  else
    echo "yq"
  fi
}

export -f findYQ
```