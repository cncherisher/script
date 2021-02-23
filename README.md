# VPS脚本
Fix add-apt-repository not found

```shell
apt-get install software-properties-common
```



IPV6 ONLY VPS GitHub Host

```shell
2a04:4e42::133 assets-cdn.github.com
2a04:4e42::133 camo.githubusercontent.com
2a04:4e42::133 cloud.githubusercontent.com
2a04:4e42::133 gist.githubusercontent.com
2a04:4e42::133 avatars.githubusercontent.com
2a04:4e42::133 avatars0.githubusercontent.com
2a04:4e42::133 avatars1.githubusercontent.com
2a04:4e42::133 avatars2.githubusercontent.com
2a04:4e42::133 avatars3.githubusercontent.com
2a04:4e42::133 marketplace-images.githubusercontent.com
2a04:4e42::133 user-images.githubusercontent.com
2a04:4e42::133 raw.githubusercontent.com
```
Mainland China VPS GitHub Host
```shell
140.82.112.3 github.com
140.82.114.4 gist.github.com
185.199.108.153 assets-cdn.github.com
199.232.68.133 raw.githubusercontent.com
199.232.68.133 gist.githubusercontent.com
199.232.68.133 cloud.githubusercontent.com
199.232.68.133 camo.githubusercontent.com
199.232.68.133 avatars0.githubusercontent.com
199.232.68.133 avatars1.githubusercontent.com
199.232.68.133 avatars2.githubusercontent.com
199.232.68.133 avatars3.githubusercontent.com
199.232.68.133 avatars4.githubusercontent.com
199.232.68.133 avatars5.githubusercontent.com
199.232.68.133 avatars6.githubusercontent.com
199.232.68.133 avatars7.githubusercontent.com
199.232.68.133 avatars8.githubusercontent.com
```
一键命令编译安装 nginx

```shell
sh -c "$(curl -kfsSl https://raw.githubusercontent.com/cncherisher/script/master/nginx.sh)"
```
一键命令安装 mtproxy

```shell
wget https://www.zeroteam.top/files/mtproxy.sh && bash mtproxy.sh
wget https://raw.githubusercontent.com/cncherisher/script/master/mtproxy.sh && bash mtproxy.sh
```
测试vps是否解锁netflix

```shell
bash <(curl -sSL "https://www.zeroteam.top/files/netflix.sh")
```

一键命令安装 fail2ban

``` shell
wget https://raw.githubusercontent.com/cncherisher/script/master/fail2ban.sh && bash fail2ban.sh 2>&1 | tee fail2ban.log
```
一键命令安装oh-my-zsh

``` shell
sh -c "$(curl -kfsSl https://raw.githubusercontent.com/cncherisher/script/master/oh-my-zsh.sh)"
```
一键命令安装aria2

``` shell
wget -N https://raw.githubusercontent.com/cncherisher/aria2.sh/master/aria2.sh && chmod +x aria2.sh && ./aria2.sh
```

安装aria-mirror-bot
``` shell
git clone -b staging-4.0 --single-branch https://github.com/lzzy12/python-aria-mirror-bot
mv python-aria-mirror-bot mirror-bot && cd mirror-bot && cp config_sample.env config.env
apt install -y python3 python3-pip p7zip-full p7zip-rar curl pv jq ffmpeg gcc git locales python3-lxml
pip3 install -r requirements.txt
pip3 install cryptography pycrypto pycryptodome uvloop
nohup python3 -m bot > /dev/null 2>&1 &
```

中国大陆git clone 加速
将github.com 换为github.com.cnpmjs.org即可实现加速
