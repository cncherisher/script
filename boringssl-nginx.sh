#!/bin/bash

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }

echo "正在安装BoringSSL版Nginx"

# 设置安装版本
nginx_quic_v='1.19.10'
pcre_v='8.44'
libmmdb_v='1.5.2'
geoip2_v='3.3'
go_v='1.16.3'
headermore_v='0.33'
jemalloc_v='5.2.1'

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

# 下载 nginx
cd /usr/src/
wget https://hg.nginx.org/nginx-quic/archive/release-${nginx_quic_v}.tar.gz
tar xzf ./release-${nginx_quic_v}.tar.gz
mv nginx-quic-release-${nginx_quic_v} nginx
cd /usr/src/nginx
wget https://raw.fastgit.org/kn007/patch/master/nginx_with_quic.patch
wget https://raw.fastgit.org/kn007/patch/master/Enable_BoringSSL_OCSP.patch
patch -p01 < nginx_with_quic.patch
patch -p01 < Enable_BoringSSL_OCSP.patch

# 下载 quiche
# 开启 https
cd /usr/src/
git clone --recursive https://hub.fastgit.org/cloudflare/quiche.git --depth=1

# 下载 zlib
# 开启 gzip 压缩
cd /usr/src/
git clone https://hub.fastgit.org/cloudflare/zlib.git zlib --depth=1
cd zlib
make -f Makefile.in distclean

# 下载 ngx_brotli
# 开启 brotli 压缩
cd /usr/src/
git clone --recursive https://hub.fastgit.org/google/ngx_brotli.git --depth=1

# 下载 pcre
# 用于正则
cd /usr/src/
wget https://ftp.pcre.org/pub/pcre/pcre-${pcre_v}.tar.gz
tar zxf ./pcre-${pcre_v}.tar.gz

# GeoIP
cd /usr/src/
# install libmaxminddb
if [ ! -e "/usr/local/lib/libmaxminddb.so" ]; then 
	wget https://download.fastgit.org/maxmind/libmaxminddb/releases/download/${libmmdb_v}/libmaxminddb-${libmmdb_v}.tar.gz
	tar xaf libmaxminddb-${libmmdb_v}.tar.gz
	cd libmaxminddb-${libmmdb_v}/
	./configure
	make -j "$(nproc)"
	make install
	ldconfig
	cd ../ 
fi

wget https://download.fastgit.org/leev/ngx_http_geoip2_module/archive/${geoip2_v}.tar.gz
tar xaf ${geoip2_v}.tar.gz

rm -rf /opt/geoip
mkdir /opt/geoip
cd /opt/geoip
wget https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-ASN.mmdb
wget https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-City.mmdb
wget https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb

# 安装golang
if [ ! -d "/usr/local/go" ]; then 
	wget https://mirrors.ustc.edu.cn/golang/go${go_v}.linux-amd64.tar.gz
	tar -C /usr/local -xzf go${go_v}.linux-amd64.tar.gz
	echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile
	/usr/local/go/bin/go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,direct
fi

# 安装rust
if [ ! -e "$HOME/.cargo/bin/cargo" ]; then 
curl https://sh.rustup.rs -sSf | sh -s -- -y
cat > $HOME/.cargo/config <<EOF
[source.crates-io]
registry = "https://github.com/rust-lang/crates.io-index"

# 指定镜像
replace-with = 'rustcc2'

# 清华大学
[source.tuna]
registry = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git"

# 中国科学技术大学
[source.ustc]
registry = "git://mirrors.ustc.edu.cn/crates.io-index"

# 上海交通大学
[source.sjtu]
registry = "https://mirrors.sjtug.sjtu.edu.cn/git/crates.io-index"

# rustcc社区
[source.rustcc0]
registry = "https://code.aliyun.com/rustcc/crates.io-index.git"

[source.rustcc1]
registry="git://crates.rustcc.cn/crates.io-index"

[source.rustcc2]
registry="git://crates.rustcc.com/crates.io-index"
EOF

source $HOME/.cargo/env
fi

# fancyindex
cd /usr/src/
git clone https://hub.fastgit.org/aperezdc/ngx-fancyindex.git --depth=1
mv ngx-fancyindex fancyindex

# webdav
cd /usr/src/
git clone https://hub.fastgit.org/arut/nginx-dav-ext-module.git --depth=1

# cache purge模块
cd /usr/src/
git clone https://hub.fastgit.org/FRiCKLE/ngx_cache_purge.git --depth=1

# More Headers
cd /usr/src/
wget https://download.fastgit.org/openresty/headers-more-nginx-module/archive/v${headermore_v}.tar.gz
tar xaf v${headermore_v}.tar.gz

# nginx vhost状态模块
cd /usr/src/
git clone https://hub.fastgit.org/vozlt/nginx-module-vts.git --depth=1

# 下载安装 jemalloc
# 更好的内存管理
if [ ! -e "/usr/local/lib/libjemalloc.so" ]; then 
	cd /usr/src/
	wget https://download.fastgit.org/jemalloc/jemalloc/releases/download/${jemalloc_v}/jemalloc-${jemalloc_v}.tar.bz2
	tar xjf jemalloc-${jemalloc_v}.tar.bz2
	cd jemalloc-${jemalloc_v}
	./configure
	make -j$(nproc) && make install
	echo '/usr/local/lib' >> /etc/ld.so.conf.d/local.conf
	ldconfig
	if [ $? -ne 0 ];then  
		echo "jemalloc install failed!" && exit 1 
	fi
fi

# 关闭 nginx 的 debug 模式
sed -i 's@CFLAGS="$CFLAGS -g"@#CFLAGS="$CFLAGS -g"@' /usr/src/nginx/auto/cc/gcc

#configure参数
NGINX_OPTIONS="
	--user=www-data \
	--group=www-data \
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--with-ld-opt=-Ljemalloc \
	--with-ld-opt=-L../quiche/deps/boringssl/build/ssl \
	--with-ld-opt=-L../quiche/deps/boringssl/build/crypto \
	--with-cc-opt=-Wno-deprecated-declarations \
	--with-cc-opt=-Wno-ignored-qualifiers \
	--with-cc-opt=-I../quiche/deps/boringssl/include \
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
	--with-http_addition_module \
	--with-http_auth_request_module \
	--with-http_dav_module \
	--with-http_degradation_module \
	--with-http_flv_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_mp4_module \
	--with-http_random_index_module \
	--with-http_realip_module \
	--with-http_secure_link_module \
	--with-http_slice_module \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-http_sub_module \
	--with-http_v2_module \
	--with-http_v2_hpack_enc \
	--with-http_v3_module \
	--with-openssl=../quiche/deps/boringssl \
	--with-quiche=../quiche \
	--with-pcre=../pcre-${pcre_v} \
	--with-pcre-jit \
	--with-stream \
	--with-stream_realip_module \
	--with-stream_ssl_module \
	--with-stream_ssl_preread_module \
	--with-zlib=../zlib --with-http_gzip_static_module"

NGINX_EXTRA_MODULES="
	--add-module=../ngx_brotli \
	--add-module=../ngx_http_geoip2_module-${geoip2_v} --with-stream \
	--add-module=../fancyindex \
	--add-module=../nginx-dav-ext-module \
	--add-module=../ngx_cache_purge \
	--add-module=../headers-more-nginx-module-${headermore_v} \
	--add-module=../nginx-module-vts"

# 编译安装 nginx
cd /usr/src/nginx
./auto/configure $NGINX_OPTIONS $NGINX_MODULES $NGINX_EXTRA_MODULES

if [ $? -ne 0 ];then  
    echo "configure failed!" && exit 1 
fi

make -j$(nproc) && make install

if [ $? -ne 0 ];then  
    echo "compile failed!" && exit 1 
fi

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
	include koi-utf;
	charset utf-8;
	charset_types text/xml text/plain text/vnd.wap.wml
				  application/javascript application/x-javascript
				  application/rss+xml text/css;
    override_charset on;
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
	gzip_comp_level 9;
	gzip_min_length 150;
    gzip_static on;
	gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;
	gzip_disable "MSIE [1-6]\.(?!.*SV1)";

	# Brotli
    brotli on;
    brotli_static on;
    brotli_min_length 150;
    brotli_window 16m;
    brotli_buffers 2048 4k;
    brotli_comp_level 6;
	brotli_types *;

	include vhost/*.conf;
}
EOF

# 创建 nginx 服务进程
mkdir -p /usr/lib/systemd/system/ 
cat > /usr/lib/systemd/system/nginx.service <<EOF
[Unit]
Description=A high performance web server and a reverse proxy server
After=syslog.target network.target network.service

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPost=/bin/sleep 0.1
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/conf/nginx.conf
ExecStart=/usr/sbin/nginx -c /etc/nginx/conf/nginx.conf
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/usr/sbin/nginx -s stop
Restart=on-abort

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

echo "Nginx安装完成"
