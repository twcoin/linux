#!/bin/bash
#apt update && apt install -y wget curl htop file socat
#proxy
#export http_proxy="http://127.0.0.1:20172"
#export https_proxy="http://127.0.0.1:20172"
cd ~ && touch acme.sh && chmod +x acme.sh
ln -sf ~/acme.sh /usr/local/bin/zs
githubusercontent_URL="https://raw.githubusercontent.com/twcoin/linux/main/sh/acme.sh"
giteebusercontent_URL="https://gitee.com/foxfix/linux/raw/master/sh/acme.sh"
curl -L -O $githubusercontent_URL && chmod +x acme.sh
