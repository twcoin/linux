#!/bin/bash
#apt update && apt install wget curl htop file socat -y
cd ~ && touch acme.sh && chmod +x acme.sh
ln -sf ~/acme.sh /usr/local/bin/zs
githubusercontent_URL="https://raw.githubusercontent.com/twcoin/linux/main/sh/acme.sh"
curl -L -O $githubusercontent_URL && chmod +x acme.sh
