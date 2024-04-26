# README.md

Tries to be a thing that can 'manage' applications on an ubuntu machine. The why is because of [https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/](https://quotidian-ennui.github.io/blog/2023/12/01/wsl2-or-mingw/)

It's not intended to be that useful to anyone else, but if you want to use it, you can (but don't hold me accountable; you're good enough to want to use this, you're good enough to understand bash scripts).

## Usage

> All in all from a `wsl --install Debian|Ubuntu` or similar you should have everything ready toolwise in ~10 minutes (there's a lot of network traffic).
>

### WSL2 Bootstrap

If you're installing on WSL2 then you need to enable systemd; since you're editing wsl.conf then you'll need to restart WSL (`wsl --shutdown` etc.)

```bash
bsh ❯ cat /etc/wsl.conf
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = false

[network]
generateResolvConf = false

[boot]
systemd=true
```

Because I have `generateResolveConf=false` I maintain my own resolv.conf; allowing WSL to generate the resolv.conf can be problematic (for reasons). If `powershell.exe -Command "Get-DnsClientServerAddress -AddressFamily ipv4 | Select-Object -ExpandProperty ServerAddresses" | sed 's/\r//g' | sort -u | xargs -n 1 echo nameserver` gives you something different to what's in the default resolv.conf, then you probably want to manage your own.

```bash
bsh ❯ cat /etc/resolv.conf
nameserver 8.8.8.8
```

Since you're editing wsl.conf and doing a restart, now would be a good time to check your `.wslconfig` which controls some global parameters; you can read more at <https://learn.microsoft.com/en-us/windows/wsl/wsl-config> but I don't go for the default behaviour. Your values will be your own, I have the sysctl setting for open/elasticsearch.

```pwsh
PS C:\Users\QuotidianEnnui> cat .\.wslconfig
[wsl2]
processors=12
memory=24GB
swap=12GB
localhostForwarding=true
guiApplications=true
kernelCommandLine="sysctl.vm.max_map_count=262144"

[experimental]
autoMemoryReclaim=gradual
```

### Optional security liability

This is obviously a terrible idea.

```bash
echo "$USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/lenient
```

### The Meat

- You may need to do a `wsl.exe --shutdown` dance after `bootstrap.sh baseline`. We will try to modify /etc/wsl.conf if it doesn't already exist to enable systemd (because docker wants it) and we do some shenanigans to binfmt to stop it from making wslview sad.

```bash
# to install the apt repos we need
./bootstrap.sh repos
# to install some initial tooling
./bootstrap.sh baseline
# Now you will need to know your ghcli token info
just init
# Install all the tools
just tools
# choose your sdk poison
just sdk help
```

### Fine control over behaviour

Various environment variables control behaviour.

- `SKIP_DOCKER` | `DPM_SKIP_DOCKER` set to any value if you don't want docker to be installed.
- `DPM_TOOLS_YAML` can be set to your custom tools build path.
- `DPM_SKIP_GHCLI_CONFIG` - set to any value if you want to skip github-cli configuration (and authentication etc.).
- `DPM_SKIP_FZF_PROFILE` - set to any value to skip bashrc shenanigans by `fzf-git`

## Notes

- I also do this before I start.

```bash
sudo apt update && sudo apt -y install vim zip unzip net-tools git
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

- `just` is installed during `bootstrap.sh baseline` via gh-release-install; it gets ovewritten again when you do `just tools`
- `yq` will be installed during `just tools` if it doesn't already exist (and promptly overwritten by the tool installation); previously we used docker, but people might not want docker all the time every time.
- Keeps a track of the files its installed in `~/.config/ubuntu-dpm/installed-versions` so it doesn't try to install the same version of things repeatedly.
