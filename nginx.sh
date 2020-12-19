#!/bin/bash

cat << EOF

正在安装Nginx

EOF

# 设置安装版本
openssl_v='1_1_1i'
nginx_v='1.19.6'
pcre_v='8.44'
PageSpeed_v='1.14.33.1-RC1'
jemalloc_v='5.2.1' 
libmmdb_v='1.4.3'
geoip2_v='3.3'

# 安装依赖
if [ -e "/usr/bin/yum" ]; then
  yum update -y
  yum install build-essential ca-certificates wget curl libpcre3 libpcre3-dev autoconf unzip automake libtool tar git libssl-dev zlib1g-dev uuid-dev lsb-release libxml2-dev libxslt1-dev cmake -y
fi
if [ -e "/usr/bin/apt-get" ]; then
  apt-get update -y
  apt-get install build-essential ca-certificates wget curl libpcre3 libpcre3-dev autoconf unzip automake libtool tar git libssl-dev zlib1g-dev uuid-dev lsb-release libxml2-dev libxslt1-dev cmake -y
fi

# 准备
rm -rf /usr/src/
mkdir -p /usr/src/
mkdir -p /var/log/nginx/
useradd -s /sbin/nologin -M www-data

# 下载 openssl
# 开启 https
cd /usr/src/
wget https://github.com/openssl/openssl/archive/OpenSSL_${openssl_v}.tar.gz 
tar xzf OpenSSL_${openssl_v}.tar.gz
mv openssl-OpenSSL_${openssl_v} openssl

# 下载 nginx
cd /usr/src/
wget https://nginx.org/download/nginx-${nginx_v}.tar.gz
tar zxf ./nginx-${nginx_v}.tar.gz 
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
wget https://ftp.pcre.org/pub/pcre/pcre-${pcre_v}.tar.gz
tar zxf ./pcre-${pcre_v}.tar.gz

# 下载 openssl-patch
# 给 openssl 打补丁，用于开启更多 https 支持
cd /usr/src/
git clone https://github.com/hakasenyang/openssl-patch.git
cd /usr/src/openssl 
patch -p1 < ../openssl-patch/openssl-equal-1.1.1e-dev_ciphers.patch

cd /usr/src/
git clone https://github.com/kn007/patch.git nginx-patch
cd /usr/src/nginx
patch -p1 < ../nginx-patch/nginx.patch

# 下载安装pingos模块
# 流媒体支持
cd /usr/src/
git clone https://github.com/pingostack/pingos.git

# GeoIP
cd /usr/src/
# install libmaxminddb
wget https://github.com/maxmind/libmaxminddb/releases/download/${libmmdb_v}/libmaxminddb-${libmmdb_v}.tar.gz
tar xaf libmaxminddb-${libmmdb_v}.tar.gz
cd libmaxminddb-${libmmdb_v}/
./configure
make -j "$(nproc)"
make install
ldconfig

cd ../ 
wget https://github.com/leev/ngx_http_geoip2_module/archive/${geoip2_v}.tar.gz
tar xaf ${geoip2_v}.tar.gz

rm -rf /opt/geoip
mkdir /opt/geoip
cd /opt/geoip
wget https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb
wget https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb

# fancyindex
cd /usr/src/
git clone https://github.com/aperezdc/ngx-fancyindex.git
mv ngx-fancyindex fancyindex

# webdav
git clone https://github.com/arut/nginx-dav-ext-module.git

# 下载安装 jemalloc
# 更好的内存管理
cd /usr/src/
wget https://github.com/jemalloc/jemalloc/releases/download/${jemalloc_v}/jemalloc-${jemalloc_v}.tar.bz2
tar xjf jemalloc-${jemalloc_v}.tar.bz2
cd jemalloc-${jemalloc_v}
./configure
make -j$(nproc) && make install
echo '/usr/local/lib' >> /etc/ld.so.conf.d/local.conf
ldconfig

# 关闭 nginx 的 debug 模式
sed -i 's@CFLAGS="$CFLAGS -g"@#CFLAGS="$CFLAGS -g"@' /usr/src/nginx/auto/cc/gcc

#configure参数
NGINX_OPTIONS="
	--user=www-data \
	--group=www-data \
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--with-ld-opt=-ljemalloc \
	--with-cc-opt=-Wno-deprecated-declarations \
	--with-cc-opt=-Wno-ignored-qualifiers
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp"
	
NGINX_MODULES="
	--with-compat \
	--with-file-aio \
	--with-threads \
	--with-http_v2_module \
	--with-http_v2_hpack_enc \
	--with-http_realip_module \
	--with-http_auth_request_module \
	--with-http_stub_status_module \
	--with-http_addition_module \
	--with-http_dav_module \
	--with-http_degradation_module \
	--with-http_secure_link_module \
	--with-http_sub_module \
	--with-http_flv_module \
	--with-http_mp4_module \
	--with-openssl=../openssl \
	--with-http_ssl_module \
	--with-pcre=../pcre-${pcre_v} --with-pcre-jit \
	--with-zlib=../zlib --with-http_gzip_static_module \
	--with-stream \
	--with-stream_ssl_module \
	--with-stream_ssl_preread_module"

NGINX_EXTRA_MODULES="
	--add-module=../ngx_brotli \
	--add-module=../pingos/modules/nginx-rtmp-module \
	--add-module=../pingos/modules/nginx-client-module \
	--add-module=../pingos/modules/nginx-multiport-module \
	--add-module=../pingos/modules/nginx-toolkit-module \
	--add-module=../ngx_http_geoip2_module-${geoip2_v}
	--add-module=../fancyindex
	--add-module=../nginx-dav-ext-module"

# 编译安装 nginx
cd /usr/src/nginx
./configure $NGINX_OPTIONS $NGINX_MODULES $NGINX_EXTRA_MODULES

make -j$(nproc) && make install

# 创建 nginx 全局配置
cat > "/etc/nginx/conf/nginx.conf" << EOF
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
  brotli_buffers 16 8k;
  brotli_static on;
  brotli_types *;

  include vhost/*.conf;
}
EOF

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
mkdir -p /var/cache/nginx
cat > "/etc/nginx/conf/vhost/default.conf" << EOF
server {
  listen 80;
  root /wwwroot/default;
  location / {
    index  index.html;
  }
}
EOF

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

#从apt源中屏蔽nginx
if [[ $(lsb_release -si) == "Debian" ]] || [[ $(lsb_release -si) == "Ubuntu" ]]; then
	cd /etc/apt/preferences.d/
	echo -e 'Package: nginx*\nPin: release *\nPin-Priority: -1' >nginx-block
fi

cat << EOF

Nginx安装完成

EOF
