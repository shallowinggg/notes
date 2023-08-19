# use ustc source
mkdir -p /usr/local/etc/pkg/repos
echo "FreeBSD: {
  url: "pkg+http://mirrors.ustc.edu.cn/freebsd-pkg/${ABI}/latest",
}" >> /usr/local/etc/pkg/repos/FreeBSD.conf
pkg update -f

# use zsh
pkg install --yes wget curl git vim emacs zsh
chsh -s zsh
exec zsh

# use oh-my-zsh
sh -c "$(wget https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
exec zsh

# install frp
wget https://github.com/fatedier/frp/releases/download/v0.45.0/frp_0.45.0_freebsd_amd64.tar.gz