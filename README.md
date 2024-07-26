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
just init
# If you are one to use the github cli
# just ghcli
# Install all the tools
just tools
# choose your sdk poison
just sdk help
# Install tooling distributed as archives
# Not done by default, because requires github token configuration
just install archives
```

### Fine control over behaviour

Various environment variables control behaviour.

- `SKIP_DOCKER` | `DPM_SKIP_DOCKER` set to any value if you don't want docker to be installed.
- `DPM_TOOLS_YAML` - can be set to your custom tools yaml path.
- `DPM_TOOLS_ADDITIONS_YAML` - can be set to an additional tools yaml path, will be merged with base tools.yml
- `DPM_REPO_YAML` - can be set to your custom repo yaml path
- `DPM_ARCHIVES_YAML` - can be set to your custom zip yaml path
- `DPM_REPO_ADDITIONS_YAML` - can be set to an additional repos yaml path, will be merged with base repos.yml
- `DPM_ARCHIVE_ADDITIONS_YAML` - can be set to an additional zip yaml path, will be merged with base archives.yml
- `DPM_SDK_YAML` - can be set to your custom sdk yaml path
- `DPM_SKIP_FZF_PROFILE` - set to any value to skip bashrc shenanigans by `fzf-git`
- `DPM_SKIP_GO_PROFILE` - set to any value to skip profile modifications by `go-nv/goenv` (via _just sdk goenv_)
  - if you opt to use `ankitcharolia/goenv` then this always modifies your profile (via _just sdk go_)
- `DPM_SKIP_JAVA_PROFILE` - set to any value to skip profile modifications by sdkman (via _just sdk java_)
- `DPM_SKIP_NVM_PROFILE` - set to any value to skip profile modifications by nvm (via _just sdk nvm_)
- `DPM_SKIP_RVM_PROFILE` - set to any value to skip profile modifications by rvm (via _just sdk rvm_)
- `DPM_SKIP_RUST_PROFILE` - set to any value to skip profile modifications by rustup (via _just sdk rust_)
- `DPM_SKIP_ARCHIVES_PROFILE` - set to any value to skip profile modifications by archives (via _just install archives_)
- `DPM_BASH_PROFILE_FILE` - defaults to $HOME/.bashrc but can be set to a different value for '_sdk goenv, sdk rust, install archives, fzf-git_)

> The various YAML files should be self explanatory and control
>
> - what binary tools are installed (tools.yml)
> - what sdk tooling is installed (via sdkman|rustup|rvm|nvm etc.) (sdk.yml)
> - what github projects are 'cloned' into the local filesystem as supporting tools (repos.yml)
> - what github distribution zips are downloaded and extracted (archives.yml)

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
