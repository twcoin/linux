#!/usr/bin/env bash
#find / -name geo*
set -e
#进入用户目录
cd ~
chmod +x up-geo-data.sh

#创建geo目录
mkdir -p /usr/share/xray /usr/share/v2ray
#xray geo路径
geodata_xray="/usr/share/xray"
#v2ray geo路径
geodata_v2ray="/usr/share/v2ray"
#geo临时路径
tmp_folder="/tmp"

GREEN='\033[0;32m'
NC='\033[0m'

cd $tmp_folder
echo -e "${GREEN}>>> change directory...${NC}"

GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOIP_URL_CDN="https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat"
#echo -e "${GREEN}>>> downloading and overwrite geoip.dat files...${NC}"
echo -e "${GREEN}>>> downloading geoip.dat files...${NC}"
curl -L -O $GEOIP_URL
#curl -L -O $GEOIP_URL_CDN

GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
GEOSITE_URL_CDN="https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat"
echo -e "${GREEN}>>> downloading geosite.dat files...${NC}"
curl -L -O $GEOSITE_URL
#curl -L -O $GEOSITE_URL_CDN

echo -e "${GREEN}>>> delete old dat files...${NC}"

chmod 755 geoip.dat
chmod 755 geosite.dat

cp -r $tmp_folder/geoip.dat $geodata_xray/geoip.dat
cp -r $tmp_folder/geosite.dat $geodata_xray/geosite.dat

cp -r $tmp_folder/geoip.dat $geodata_v2ray/geoip.dat
cp -r $tmp_folder/geosite.dat $geodata_v2ray/geosite.dat

echo -e "${GREEN}>>> file information...${NC}"
ls -l $geodata_xray/*
du -sh $geodata_xray/*
systemctl restart v2raya.service
#systemctl status v2raya.service
#/etc/init.d/v2raya restart
#/etc/init.d/v2raya status
echo -e "${GREEN}geo文件更新完成啦！${NC}"
