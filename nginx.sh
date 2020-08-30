#!/bin/bash

# 选择安装 WAF
cat << EOF

正在安装Nginx

EOF


# 安装依赖
if [ -e "/usr/bin/yum" ]; then
  yum update -y
  yum install git gcc make build-essential logrotate cron -y
fi
if [ -e "/usr/bin/apt-get" ]; then
  apt-get update -y
  apt-get install git gcc make build-essential logrotate cron -y
fi

# 准备
rm -rf /usr/src/
mkdir -p /usr/src/
mkdir -p /var/log/nginx/
useradd -s /sbin/nologin -M www-data

# 下载 openssl
# 开启 https
cd /usr/src
wget https://github.com/openssl/openssl/archive/OpenSSL_1_1_1.tar.gz 
tar xzvf OpenSSL_1_1_1.tar.gz
mv openssl-OpenSSL_1_1_1 openssl

# 下载 nginx
cd /usr/src/
nginx_v='1.19.2'
wget https://nginx.org/download/nginx-${nginx_v}.tar.gz
tar zxvf ./nginx-${nginx_v}.tar.gz 
mv nginx-${nginx_v} nginx

# 下载 zlib
# 开启 gzip 压缩
cd /usr/src/
git clone https://github.com/cloudflare/zlib.git zlib
cd zlib
make -f Makefile.in distclean

# 下载 ngx_brotli
# 开启 brotli 压缩
cd /usr/src/
git clone --recursive https://github.com/google/ngx_brotli.git

# 下载 pcre
# 用于正则
cd /usr/src/
wget https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz
tar zxf ./pcre-8.43.tar.gz

# 下载 openssl-patch
# 给 openssl 打补丁，用于开启更多 https 支持
cd /usr/src/
git clone https://github.com/hakasenyang/openssl-patch.git
cd /usr/src/openssl 
patch -p1 < ../openssl-patch/openssl-equal-1.1.1a_ciphers.patch

cd /usr/src/
git clone https://github.com/kn007/patch.git nginx-patch
cd /usr/src/nginx
patch -p1 < ../nginx-patch/nginx.patch

# 下载安装 jemalloc
# 更好的内存管理
cd /usr/src/
wget https://github.com/jemalloc/jemalloc/releases/download/5.2.1/jemalloc-5.2.1.tar.bz2
tar xjvf jemalloc-5.2.1.tar.bz2
cd jemalloc-5.2.1
./configure
make -j$(nproc) && make install
echo '/usr/local/lib' >> /etc/ld.so.conf.d/local.conf
ldconfig

# 关闭 nginx 的 debug 模式
sed -i 's@CFLAGS="$CFLAGS -g"@#CFLAGS="$CFLAGS -g"@' /usr/src/nginx/auto/cc/gcc

# 编译安装 nginx
cd /usr/src/nginx
./configure \
--user=www-data --group=www-data \
--prefix=/etc/nginx \
--sbin-path=/usr/sbin/nginx \
--with-compat --with-file-aio --with-threads \
--with-http_v2_module --with-http_v2_hpack_enc \
--with-http_realip_module \
--with-http_flv_module --with-http_mp4_module \
--with-openssl=../openssl --with-http_ssl_module \
--with-pcre=../pcre-8.43 --with-pcre-jit \
--with-zlib=../zlib --with-http_gzip_static_module \
--add-module=../ngx_brotli \
--with-stream --with-stream_ssl_module --with-stream_ssl_preread_module \
--with-ld-opt=-ljemalloc 

make -j$(nproc) && make install

# 下载配置 ngx_lua_waf
cd /etc/nginx/conf/
rm -rf /etc/nginx/conf/waf
git clone https://github.com/xzhih/ngx_lua_waf.git waf 
mkdir -p /etc/nginx/logs/waf 
chown www-data:www-data /etc/nginx/logs/waf 
cat > /etc/nginx/conf/waf.conf << EOF
lua_load_resty_core off;
lua_shared_dict limit 20m;
lua_package_path "/etc/nginx/conf/waf/?.lua";
init_by_lua_file "/etc/nginx/conf/waf/init.lua";
access_by_lua_file "/etc/nginx/conf/waf/access.lua";
EOF

# 创建 nginx 全局配置
cat > "/etc/nginx/conf/nginx.conf" << OOO
user www-data www-data;
pid /var/run/nginx.pid;
worker_processes auto;
worker_rlimit_nofile 65535;

events {
  use epoll;
  multi_accept on;
  worker_connections 65535;
}

http {
  charset utf-8;
  sendfile on;
  aio threads;
  directio 512k;
  tcp_nopush on;
  tcp_nodelay on;
  server_tokens off;
  log_not_found off;
  types_hash_max_size 2048;
  client_max_body_size 16M;

  # MIME
  include mime.types;
  default_type application/octet-stream;

  # Logging
  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log warn;

  # Gzip
  gzip on;
  gzip_vary on;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;
  gzip_disable "MSIE [1-6]\.(?!.*SV1)";

  # Brotli
  brotli on;
  brotli_comp_level 6;
  brotli_static on;
  brotli_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

  include vhost/*.conf;
  include waf.conf;
}
OOO

# 创建 nginx 服务进程
mkdir -p /usr/lib/systemd/system/ 
cat > /usr/lib/systemd/system/nginx.service <<EOF
[Unit]
Description=nginx - high performance web server
After=network.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPost=/bin/sleep 0.1
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/conf/nginx.conf
ExecStart=/usr/sbin/nginx -c /etc/nginx/conf/nginx.conf
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/usr/sbin/nginx -s stop

[Install]
WantedBy=multi-user.target
EOF

# 创建 nginx 日志规则 (自动分割)
cat > /etc/logrotate.d/nginx << EOF
/var/log/nginx/*.log {
  daily
  missingok
  rotate 52
  delaycompress
  notifempty
  create 640 www-data www-data
  sharedscripts
  postrotate
  if [ -f /var/run/nginx.pid ]; then
    kill -USR1 \`cat /var/run/nginx.pid\`
  fi
  endscript
}
EOF
ldconfig

# 配置默认站点
mkdir -p /wwwroot/
cp -r /etc/nginx/html /wwwroot/default
mkdir -p /etc/nginx/conf/vhost/
mkdir -p /etc/nginx/conf/ssl/
cat > "/etc/nginx/conf/vhost/default.conf" << EEE
server {
  listen 80;
  root /wwwroot/default;
  location / {
    index  index.html;
  }
}
EEE

# 配置站点目录权限
chown -R www-data:www-data /wwwroot/
find /wwwroot/ -type d -exec chmod 755 {} \;
find /wwwroot/ -type f -exec chmod 644 {} \;

# 开启 nginx 服务进程
ln -s /usr/sbin/nginx /usr/bin/nginx
systemctl unmask nginx.service
systemctl daemon-reload
systemctl enable nginx
systemctl stop nginx
systemctl start nginx
