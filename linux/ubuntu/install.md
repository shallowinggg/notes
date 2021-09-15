# install go

[Official Tutorial](https://github.com/golang/go/wiki/Ubuntu)

```shell
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt update
sudo apt install golang-go
```

# install java

```shell
sudo apt install openjdk-8-jdk
sudo apt install openjdk-11-jdk
```

## Set default version

```shell
sudo update-alternatives --config java
```

# install sdk

[Official](https://sdkman.io/install)

```shell
sudo apt-get install zip
sudo apt-get install unzip
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

sdk version
```

# install gradle

[Official](https://gradle.org/install/)

```shell
sdk install gradle 7.2
```

# install node

[nvm install](https://github.com/nvm-sh/nvm#installing-and-updating)

```shell
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
source ~/.bashrc
nvm install node
```

# install nvim

```shell
sudo apt-get install software-properties-common

sudo add-apt-repository ppa:neovim-ppa/stable
sudo apt update
sudo apt install -y neovim

mkdir ~/.config
mkdir ~/.config/nvim
vim ~/.config/nvim/init.vim
# configure
nvim +GoInstallBinaries
```

### Configuration Files

* [init.vim](./init.vim)
* [coc-settings.json](./coc-settings.json)

[gopls](https://github.com/golang/tools/blob/master/gopls/README.md)
`coc-settings.json` for golang

# install vim-plug

[Official](https://github.com/junegunn/vim-plug)

```shell
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
```

# install kvm
1. install dependencies

```shell
sudo apt install qemu qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager
```

2. edit `/etc/default/grub`

```
# /etc/default/grub

`GRUB_CMDLINE_LINUX="intel_iommu=on"`
```

Then run:

```shell
update-grub
```

3. `systemctl reboot`
