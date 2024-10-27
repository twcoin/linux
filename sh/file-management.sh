#!/bin/bash
## Modified: 2024-10-11
##=======================================================
#红色
RED="\033[31m"
#绿色
GREEN="\033[32m"
#黄色
YELLOW="\033[33m"
#白色
PLAIN="\033[0m"
#蓝色
BLUE="\033[0;34m"
#灰色
GREY="\e[37m"
#紫色
PURPLE='\033[35m'
#自定义颜色
CUSTOM='\033[96m'
C_hui=$GREY
C_hong=$RED
C_lv=$GREEN
C_huang=$YELLOW
C_lan=$BLUE
C_bai=$PLAIN
C_zi=$PURPLE
C_zdy=$CUSTOM##=======================================================
function App_Detection() {
while true; do
	if docker inspect "down-web-dufs" &>/dev/null; then
		echo -e ">>> ${C_lan}应用 dufs …… ${C_bai}[${C_lv}"无需重复部署"${C_bai}]"
		exit
		#return
		#break
	else
		echo -e ">>> ${C_lan}应用 dufs …… ${C_bai}[${C_huang}"Creating"${C_bai}]"
	fi
done
}
##=======================================================
function FILE_Creating() {
echo -e ""
echo -e ""
m_dir_paths=("/home/FileManagement/shell" "/home/FileManagement/docker-compose" "/home/FileManagement/nginx" "/home/FileManagement/other" "/home/FileManagement/other/dat" "/home/FileManagement/other/v2rayN")
for dir_path in "${m_dir_paths[@]}"; do
	if [ ! -d "$dir_path" ]; then
		echo -e ">>> ${C_lan}目录 "$dir_path" …… ${C_bai}[${C_hong}"Lost"${C_bai}]"
		echo -e ">>> ${C_lan}目录 "$dir_path" …… ${C_bai}[${C_huang}"Creating"${C_bai}]"
		mkdir -p "$dir_path"
		echo -e ">>> ${C_lan}目录 "$dir_path" …… ${C_bai}[${C_lv}"Normal"${C_bai}]"
	else
		echo -e ">>> ${C_lan}目录 "$dir_path" …… ${C_bai}[${C_lv}"Normal"${C_bai}]"
	fi
done
echo -e ""
echo -e ""
m_file_paths=(""$m_dir_paths"/ChangeMirrors.sh" ""$m_dir_paths"/DockerInstallation.sh" ""$m_dir_paths"/kejilion.sh")
for file_path in "${m_file_paths[@]}"; do
	if [ ! -f "$file_path" ]; then
		echo -e ">>> ${C_lan}文件 "$file_path" …… ${C_bai}[${C_hong}"Lost"${C_bai}]"
		echo -e ">>> ${C_lan}文件 "$file_path" …… ${C_bai}[${C_huang}"Creating"${C_bai}]"
		touch "$file_path"
		echo -e ">>> ${C_lan}文件 "$file_path" …… ${C_bai}[${C_lv}"Normal"${C_bai}]"
	else
		echo -e ">>> ${C_lan}文件 "$file_path" …… ${C_bai}[${C_lv}"Normal"${C_bai}]"
	fi
done
}
##=======================================================
App_Detection
FILE_Creating
echo -e ""
echo -e ""
data_path="/home"
curl -K ~/shell/curl-down -kfSL -o "$data_path"/file-management.yml https://raw.githubusercontent.com/twcoin/linux/refs/heads/main/sh/file-management.yml
fileuser=$(openssl rand -hex 4) ; filepassword=$(openssl rand -base64 9)
# 在 docker compose yml配置文件中进行替换
sed -i "s#fileuser#$fileuser#g" "$data_path"/file-management.yml
sed -i "s#filepassword#$filepassword#g" "$data_path"/file-management.yml
docker compose -f "$data_path"/file-management.yml up -d
echo -e ""
echo -e ">>> ${C_lan}FileManagement 访问地址 …… ${C_bai}[${C_lv}http://localhost:5000${C_bai}]"
echo -e ">>> ${C_lan}FileManagement 登陆用户 …… ${C_bai}[${C_lv}"$fileuser"${C_bai}]"
echo -e ">>> ${C_lan}FileManagement 登陆密码 …… ${C_bai}[${C_lv}"$filepassword"${C_bai}]"
exit
##=======================================================
