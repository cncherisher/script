# VPS脚本
IPV6 ONLY VPS Github Host
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

一键命令编译安装 nginx

```shell
sh -c "$(curl -kfsSl https://raw.githubusercontent.com/cncherisher/script/master/nginx.sh)"
```
一键命令安装 mtp

```shell
sh -c "$(curl -kfsSl https://raw.githubusercontent.com/cncherisher/script/master/mtp+nginx.sh)"
```
一键命令安装 fail2ban

```shell
wget https://raw.githubusercontent.com/cncherisher/script/master/fail2ban.sh && bash fail2ban.sh 2>&1 | tee fail2ban.log
```