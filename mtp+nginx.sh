#!/bin/bash

# 安装依赖
if [ -e "/usr/bin/yum" ]; then
  yum update -y
  yum install git gcc python3-pip cron -y
  pip3 install cryptography pycrypto pycryptodome uvloop
fi
if [ -e "/usr/bin/apt-get" ]; then
  apt-get update -y
  apt-get install git python3-pip cron -y
  pip3 install cryptography pycrypto pycryptodome uvloop
fi
#生成16位用户secret
user=`head -c 16 /dev/urandom | xxd -ps`

#下载mtprotoproxy
rm -rf mtprotoproxy
git clone -b stable https://github.com/alexbers/mtprotoproxy.git; 
cd mtprotoproxy

#修改配置文件
cat > ./config.py <<EOF
PORT = 2333

# name -> secret (32 hex chars)
USERS = {
    "tg":  "$user",
}

MODES = {
    # Classic mode, easy to detect
    "classic": False,

    # Makes the proxy harder to detect
    # Can be incompatible with very old clients
    "secure": False,

    # Makes the proxy even more hard to detect
    # Can be incompatible with old clients
    "tls": True
}
TLS_DOMAIN = "www.cloudflare.com"
PROXY_PROTOCOL = True

TO_CLT_BUFSIZE = 262144
TO_TG_BUFSIZE = 262144

EOF

cat >> /etc/nginx/conf/nginx.conf <<EOF
stream {
    map \$ssl_preread_server_name \$name {
        www.cloudflare.com MT; # 映射域名到合适的后端
        default LocalBackEnd;
    }
    upstream MT {
        server 127.0.0.1:2333; # 这里是mtproxy监听端口
    }
    upstream LocalBackEnd {
        server localhost:1024; # 临时的服务器
    }
    upstream RealBackEnd {
        server localhost:1025; # 真正的服务器，见下文用1025端口
    }
    server {
        listen 443 reuseport; # 对外的443端口
        proxy_pass \$name;
        proxy_protocol on; # 关键的一步，支持HAProxy的proxy_protocol
        ssl_preread on; # 预读SNI主机名
    }
    server {
        listen localhost:1024 reuseport proxy_protocol;
        proxy_pass RealBackEnd;
    }
}


EOF
# 创建 mtproxy 服务进程
mkdir -p /usr/lib/systemd/system/ 
cat >/var/run/mtp.pid <<EOF
EOF
cat > /usr/lib/systemd/system/mtp.service <<EOF
[Unit]
Description=Fast and simple to setup MTProto proxy written in Python.
After=network.target

[Service]
Type=simple
PIDFile=/root/mtprotoproxy/src/mtp.pid
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=23
PrivateTmp=true
ExecStart=/usr/bin/python3 /root/mtprotoproxy/mtprotoproxy.py

[Install]
WantedBy=multi-user.target
EOF

#开启mtproxy 服务进程
systemctl unmask mtp.service
systemctl daemon-reload
systemctl enable mtp
systemctl stop mtp
systemctl start mtp
systemctl stop nginx
systemctl start nginx