#!/bin/bash

# fonts color
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
osRelease=""
osSystemPackage=""
osSystemmdPath=""

# copy from 秋水逸冰 ss scripts
if [[ -f /etc/redhat-release ]]; then
	osRelease="centos"
	osSystemPackage="yum"
	osSystemmdPath="/usr/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "debian"; then
	osRelease="debian"
	osSystemPackage="apt-get"
	osSystemmdPath="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
	osRelease="ubuntu"
	osSystemPackage="apt-get"
	osSystemmdPath="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
	osRelease="centos"
	osSystemPackage="yum"
	osSystemmdPath="/usr/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "debian"; then
	osRelease="debian"
	osSystemPackage="apt-get"
	osSystemmdPath="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "ubuntu"; then
	osRelease="ubuntu"
	osSystemPackage="apt-get"
	osSystemmdPath="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
	osRelease="centos"
	osSystemPackage="yum"
	osSystemmdPath="/usr/lib/systemd/system/"
fi
echo "OS info: ${osRelease}, ${osSystemPackage}, ${osSystemmdPath}"

 # 安装 micro 编辑器
    if [[ ! -f "${HOME}/bin/micro" ]] ;  then
        mkdir -p ${HOME}/bin
        cd ${HOME}/bin
        curl https://getmic.ro | bash

        cp ${HOME}/bin/micro /usr/local/bin
    fi


    green "=============================="
    yellow "准备安装 ZSH"
    green "=============================="

    if [ "$osRelease" == "centos" ]; then

        sudo $osSystemPackage install zsh -y
        $osSystemPackage install util-linux-user -y

    elif [ "$osRelease" == "ubuntu" ]; then

        sudo $osSystemPackage install zsh -y

    elif [ "$osRelease" == "debian" ]; then

        sudo $osSystemPackage install zsh -y
    fi

    green "=============================="
    yellow " ZSH 安装成功, 准备安装 oh-my-zsh"
    green "=============================="

    # 安装 oh-my-zsh
    if [[ ! -d "${HOME}/.oh-my-zsh" ]] ;  then
        curl -Lo ${HOME}/ohmyzsh_install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
        chmod +x ${HOME}/ohmyzsh_install.sh
        sh ${HOME}/ohmyzsh_install.sh --unattended
    fi

    if [[ ! -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]] ;  then
        git clone "https://github.com/zsh-users/zsh-autosuggestions" "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

        # 配置 zshrc 文件
        zshConfig=${HOME}/.zshrc
        zshTheme="maran"
        sed -i 's/ZSH_THEME=.*/ZSH_THEME="'${zshTheme}'"/' $zshConfig
        sed -i 's/plugins=(git)/plugins=(git cp history z rsync colorize zsh-autosuggestions)/' $zshConfig

        zshAutosuggestionsConfig=${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
        sed -i "s/ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'/ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=1'/" $zshAutosuggestionsConfig


        # Actually change the default shell to zsh
        zsh=$(which zsh)

        if ! chsh -s "$zsh"; then
            error "chsh command unsuccessful. Change your default shell manually."
			red "https://blog.csdn.net/lftuui/article/details/60148800"
        else
            export SHELL="$zsh"
            green "===== Shell successfully changed to '$zsh'."
        fi


        echo 'alias lla="ll -ah"' >> ${HOME}/.zshrc
        echo 'alias mi="micro"' >> ${HOME}/.zshrc

        green "oh-my-zsh 安装成功, 请exit命令退出服务器后重新登陆vps服务器即可启动 oh-my-zsh!"

    fi


    # 设置vim 中文乱码
    if [[ ! -d "${HOME}/.vimrc" ]] ;  then
        cat > "${HOME}/.vimrc" <<-EOF
set fileencodings=utf-8,gb2312,gb18030,gbk,ucs-bom,cp936,latin1
set enc=utf8
set fencs=utf8,gbk,gb2312,gb18030

syntax on
set nu!

EOF
    fi