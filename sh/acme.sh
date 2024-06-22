#!/bin/bash
#Update-Time：20240615

mkdir -p /home/web /root/certs /home/docker /root/shell

cd ~ && touch acme.sh && chmod +x acme.sh
ln -sf ~/acme.sh /usr/local/bin/zs

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


red(){
	echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
	echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
	echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && red "注意：请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
	SYS="$i"
	if [[ -n $SYS ]]; then
		break
	fi
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
	if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
		SYSTEM="${RELEASE[int]}"
		if [[ -n $SYSTEM ]]; then
			break
		fi
	fi
done

[[ -z $SYSTEM ]] && red "不支持当前VPS系统, 请使用主流的操作系统" && exit 1
#返回acme-menu
back2menu() {
	echo ""
	green "所选命令操作执行完成"
	read -rp "请输入“y”退出, 或按任意键回到主菜单：" back2menuInput
	case "$back2menuInput" in
		y) exit 1 ;;
		*) acme-menu ;;
	esac
}
#
install_base(){
	if [[ ! $SYSTEM == "CentOS" ]]; then
		${PACKAGE_UPDATE[int]}
	fi
	${PACKAGE_INSTALL[int]} curl wget sudo socat openssl 
	if [[ $SYSTEM == "CentOS" ]]; then
		${PACKAGE_INSTALL[int]} cronie bind-utils
		systemctl start crond
		systemctl enable crond
	else
		${PACKAGE_INSTALL[int]} cron dnsutils
		systemctl start cron
		systemctl enable cron
	fi
}
#安装acme域名证书申请脚本
install_acme(){
	install_base
	read -rp "请输入注册邮箱 (例: admin@gmail.com, 或留空自动生成一个gmail邮箱): " acmeEmail
	if [[ -z $acmeEmail ]]; then
		autoEmail=$(date +%s%N | md5sum | cut -c 1-16)
		acmeEmail=$autoEmail@gmail.com
		yellow "已取消设置邮箱, 使用自动生成的gmail邮箱: $acmeEmail"
	fi
	curl https://get.acme.sh | sh -s email=$acmeEmail
	source ~/.bashrc
	bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
	bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
	if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
		green "Acme.sh证书申请脚本安装成功!"
	else
		red "抱歉, Acme.sh证书申请脚本安装失败"
		green "建议如下："
		yellow "1. 检查VPS的网络环境"
		yellow "2. 脚本可能跟不上时代, 建议截图发布到GitHub Issues询问"
	fi
	back2menu
}
#检测80端口是否被占用
check_80(){
	
	if [[ -z $(type -P lsof) ]]; then
		if [[ ! $SYSTEM == "CentOS" ]]; then
			${PACKAGE_UPDATE[int]}
		fi
		${PACKAGE_INSTALL[int]} lsof
	fi
	
	yellow "正在检测80端口是否占用..."
	sleep 1
	
	if [[  $(lsof -i:"80" | grep -i -c "listen") -eq 0 ]]; then
		green "检测到目前80端口未被占用"
		sleep 1
	else
		red "检测到目前80端口被其他程序被占用，以下为占用程序信息"
		lsof -i:"80"
		read -rp "如需结束占用进程请按Y，按其他键则退出 [Y/N]: " yn
		if [[ $yn =~ "Y"|"y" ]]; then
			lsof -i:"80" | awk '{print $2}' | grep -v "PID" | xargs kill -9
			sleep 1
		else
			exit 1
		fi
	fi
	   
	if [[ $SYSTEM == "CentOS" ]]; then
	 	firewall-cmd --permanent --add-port=80/tcp
		firewall-cmd --reload
		echo "TCP/80端口已开启"
	else 
	   [[ ! $SYSTEM == "CentOS" ]]
		ufw allow 80/tcp
		ufw reload
		echo "TCP/80端口已开启"  
	fi
	
}
#占用80端口申请单域名证书
acme_standalone(){
	[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && red "未安装acme.sh, 无法执行操作" && exit 1
	check_80
	WARPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
	WARPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
	if [[ $WARPv4Status =~ on|plus ]] || [[ $WARPv6Status =~ on|plus ]]; then
		wg-quick down wgcf >/dev/null 2>&1
		systemctl stop warp-go >/dev/null 2>&1
	fi
	
	ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
	ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
	
	echo ""
	yellow "在使用80端口申请模式时, 请先将您的域名解析至你的VPS的真实IP地址, 否则会导致证书申请失败"
	echo ""
	if [[ -n $ipv4 && -n $ipv6 ]]; then
		echo -e "VPS的真实IPv4地址为: ${GREEN} $ipv4 ${PLAIN}"
		echo -e "VPS的真实IPv6地址为: ${GREEN} $ipv6 ${PLAIN}"
	elif [[ -n $ipv4 && -z $ipv6 ]]; then
		echo -e "VPS的真实IPv4地址为: ${GREEN} $ipv4 ${PLAIN}"
	elif [[ -z $ipv4 && -n $ipv6 ]]; then
		echo -e "VPS的真实IPv6地址为: ${GREEN} $ipv6 ${PLAIN}"
	fi
	echo ""
	read -rp "请输入解析完成的域名: " domain
	[[ -z $domain ]] && red "未输入域名，无法执行操作！" && exit 1
	green "已输入的域名：$domain" && sleep 1
	domainIP=$(dig +short ${domain})
	
	if [[ $domainIP == $ipv6 ]]; then
		bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --listen-v6 --insecure
	fi
	if [[ $domainIP == $ipv4 ]]; then
		bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --insecure
	fi
	
	if [[ -n $(echo $domainIP | grep nginx) ]]; then
		if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
			wg-quick up wgcf >/dev/null 2>&1
		fi
		if [[ -a "/opt/warp-go/warp-go" ]]; then
			systemctl start warp-go 
		fi
		yellow "域名解析失败, 请检查域名是否正确填写或等待解析完成再执行脚本"
		exit 1
	elif [[ -n $(echo $domainIP | grep ":") || -n $(echo $domainIP | grep ".") ]]; then
		if [[ $domainIP != $ipv4 ]] && [[ $domainIP != $ipv6 ]]; then
			if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
				wg-quick up wgcf >/dev/null 2>&1
			fi
			if [[ -a "/opt/warp-go/warp-go" ]]; then
				systemctl start warp-go 
			fi
			green "域名 ${domain} 目前解析的IP: ($domainIP)"
			red "当前域名解析的IP与当前VPS使用的真实IP不匹配"
			green "建议如下："
			yellow "1. 请确保CloudFlare小云朵为关闭状态(仅限DNS), 其他域名解析或CDN网站设置同理"
			yellow "2. 请检查DNS解析设置的IP是否为VPS的真实IP"
			yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
			exit 1
		fi
	fi
	bash ~/.acme.sh/acme.sh --install-cert -d "${domain}" --key-file /root/certs/${domain}_private.key --fullchain-file /root/certs/${domain}_cert.crt --ecc
	bash ~/.acme.sh/acme.sh --install-cert -d "${domain}" --key-file /root/certs/${domain}_key.pem --fullchain-file /root/certs/${domain}_cert.pem --ecc
	checktls ${domain}  # 传递域名到checktls函数
}
#不占用80端口申请单域名证书(CF API申请)(无需解析)(不支持freenom域名)
acme_cfapiTLD(){
	[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && red "未安装Acme.sh, 无法执行操作" && exit 1
	ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
	ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
	read -rp "请输入需要申请证书的域名: " domain
	if [[ $(echo ${domain:0-2}) =~ cf|ga|gq|ml|tk ]]; then
		red "检测为Freenom免费域名, 由于CloudFlare API不支持, 故无法使用本模式申请!"
		back2menu
	fi
	read -rp "请输入CloudFlare Global API Key: " GAK
	[[ -z $GAK ]] && red "未输入CloudFlare Global API Key, 无法执行操作!" && exit 1
	export CF_Key="$GAK"
	read -rp "请输入CloudFlare的登录邮箱: " CFemail
	[[ -z $domain ]] && red "未输入CloudFlare的登录邮箱, 无法执行操作!" && exit 1
	export CF_Email="$CFemail"
	if [[ -z $ipv4 ]]; then
		bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d "${domain}" -k ec-256 --listen-v6 --insecure
	else
		bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d "${domain}" -k ec-256 --insecure
	fi
	bash ~/.acme.sh/acme.sh --install-cert -d "${domain}" --key-file /root/certs/${domain}_private.key --fullchain-file /root/certs/${domain}_cert.crt --ecc
	bash ~/.acme.sh/acme.sh --install-cert -d "${domain}" --key-file /root/certs/${domain}_key.pem --fullchain-file /root/certs/${domain}_cert.pem --ecc
	checktls ${domain}  # 传递域名到checktls函数
}
#不占用80端口申请泛域名证书(CF API申请)(无需解析)(不支持freenom域名)
acme_cfapiNTLD(){
	[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && red "未安装acme.sh, 无法执行操作" && exit 1
	ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
	ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
	read -rp "请输入需要申请证书的泛域名 (输入格式：example.com): " domain
	[[ -z $domain ]] && red "未输入域名，无法执行操作！" && exit 1
	if [[ $(echo ${domain:0-2}) =~ cf|ga|gq|ml|tk ]]; then
		red "检测为Freenom免费域名, 由于CloudFlare API不支持, 故无法使用本模式申请!"
		back2menu
	fi
	read -rp "请输入CloudFlare Global API Key: " GAK
	[[ -z $GAK ]] && red "未输入CloudFlare Global API Key, 无法执行操作！" && exit 1
	export CF_Key="$GAK"
	read -rp "请输入CloudFlare的登录邮箱: " CFemail
	[[ -z $domain ]] && red "未输入CloudFlare的登录邮箱, 无法执行操作!" && exit 1
	export CF_Email="$CFemail"
	if [[ -z $ipv4 ]]; then
		bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d "*.${domain}" -d "${domain}" -k ec-256 --listen-v6 --insecure
	else
		bash ~/.acme.sh/acme.sh --issue --dns dns_cf -d "*.${domain}" -d "${domain}" -k ec-256 --insecure
	fi
	bash ~/.acme.sh/acme.sh --install-cert -d "${domain}" --key-file /root/certs/${domain}_private.key --fullchain-file /root/certs/${domain}_cert.crt --ecc
	bash ~/.acme.sh/acme.sh --install-cert -d "${domain}" --key-file /root/certs/${domain}_key.pem --fullchain-file /root/certs/${domain}_cert.pem --ecc
	checktls ${domain}  # 传递域名到checktls函数
}
#
checktls() {
domain=$1  # 从参数获取域名
	if [[ -f /root/certs/${domain}_cert.crt && -f /root/certs/${domain}_private.key ]]; then
		if [[ -s /root/certs/${domain}_cert.crt && -s /root/certs/${domain}_private.key ]]; then
			if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
				wg-quick up wgcf >/dev/null 2>&1
			fi
			if [[ -a "/opt/warp-go/warp-go" ]]; then
				systemctl start warp-go 
			fi
			echo $domain > /root/certs/${domain}_ca.log
			sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
			echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >> /etc/crontab
			green "证书申请成功! 脚本申请到的证书 (cert.crt) 和私钥 (private.key) 文件已保存到 /root/certs 文件夹下"
			yellow "证书crt文件路径如下: /root/certs/${domain}_cert.crt"
			yellow "私钥key文件路径如下: /root/certs/${domain}_private.key"
			
			back2menu
		else
			if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
				wg-quick up wgcf >/dev/null 2>&1
			fi
			if [[ -a "/opt/warp-go/warp-go" ]]; then
				systemctl start warp-go 
			fi
			red "很抱歉，证书申请失败"
			green "建议如下: "
			yellow "1. 自行检测防火墙是否打开, 如使用80端口申请模式时, 请关闭防火墙或放行80端口"
			yellow "2. 同一域名多次申请可能会触发Let's Encrypt官方风控, 请尝试使用脚本菜单的9选项更换证书颁发机构, 再重试申请证书, 或更换域名、或等待7天后再尝试执行脚本"
			yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues询问"
			back2menu
		fi
	fi
}
#查看已申请的证书
view_cert(){
	[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "未安装acme.sh, 无法执行操作!" && exit 1
	bash ~/.acme.sh/acme.sh --list
	back2menu
}
#撤销并删除已申请的证书
revoke_cert() {
	[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "未安装acme.sh, 无法执行操作!" && exit 1
	bash ~/.acme.sh/acme.sh --list
	read -rp "请输入要撤销的域名证书 (复制Main_Domain下显示的域名): " domain
	[[ -z $domain ]] && red "未输入域名，无法执行操作!" && exit 1
	if [[ -n $(bash ~/.acme.sh/acme.sh --list | grep $domain) ]]; then
		bash ~/.acme.sh/acme.sh --revoke -d ${domain} --ecc
		bash ~/.acme.sh/acme.sh --remove -d ${domain} --ecc
		rm -rf ~/.acme.sh/${domain}_ecc
		rm -f /root/certs/${domain}_cert.crt /root/certs/${domain}_private.key
		rm -f /root/certs/${domain}_cert.pem /root/certs/${domain}_key.pem
		green "撤销${domain}的域名证书成功"
		back2menu
	else
		red "未找到${domain}的域名证书, 请自行检查!"
		back2menu
	fi
}
#手动续期已申请的证书
renew_cert() {
	[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "未安装acme.sh, 无法执行操作!" && exit 1
	bash ~/.acme.sh/acme.sh --list
	read -rp "请输入要续期的域名证书 (复制Main_Domain下显示的域名): " domain
	[[ -z $domain ]] && red "未输入域名, 无法执行操作!" && exit 1
	if [[ -n $(bash ~/.acme.sh/acme.sh --list | grep $domain) ]]; then
		bash ~/.acme.sh/acme.sh --renew -d ${domain} --force --ecc
		##bash ~/.acme.sh/acme.sh --install-cert -d "${domain}" --key-file /root/certs/${domain}_private.key --fullchain-file /root/certs/${domain}_cert.crt --ecc
		##bash ~/.acme.sh/acme.sh --install-cert -d "${domain}" --key-file /root/certs/${domain}_key.pem --fullchain-file /root/certs/${domain}_cert.pem --ecc
		checktls
		back2menu
	else
		red "未找到${domain}的域名证书，请再次检查域名输入正确"
		back2menu
	fi
}
#切换证书颁发机构
switch_provider(){
	yellow "请选择证书提供商, 默认通过 Letsencrypt.org 来申请证书 "
	yellow "如果证书申请失败, 例如一天内通过 Letsencrypt.org 申请次数过多, 可选 BuyPass.com 或 ZeroSSL.com 来申请."
	echo -e " ${GREEN}1.${PLAIN} Letsencrypt.org"
	echo -e " ${GREEN}2.${PLAIN} BuyPass.com"
	echo -e " ${GREEN}3.${PLAIN} ZeroSSL.com"
	read -rp "请选择证书提供商 [1-3，默认1]: " provider
	case $provider in
		2) bash ~/.acme.sh/acme.sh --set-default-ca --server buypass && green "切换证书提供商为 BuyPass.com 成功！" ;;
		3) bash ~/.acme.sh/acme.sh --set-default-ca --server zerossl && green "切换证书提供商为 ZeroSSL.com 成功！" ;;
		*) bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt && green "切换证书提供商为 Letsencrypt.org 成功！" ;;
	esac
	
	back2menu
}
#卸载acme域名证书申请脚本
uninstall() {
	[[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && yellow "未安装Acme.sh, 卸载程序无法执行!" && exit 1
	~/.acme.sh/acme.sh --uninstall
	sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
	rm -rf ~/.acme.sh
	green "Acme  一键申请证书脚本已彻底卸载!"
}
#设置系统源
1_Change_Mirrors() {
echo ""
echo ""
echo ""
echo ""
sh_shell="/root/shell"
cd $sh_shell && touch ChangeMirrors.sh
sh_v_new=$(curl -s https://gitee.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh | grep Modified | awk '{match($0, /20/); print substr($0, RSTART)}' | head -n 1)
sh_v=$(cat $sh_shell/ChangeMirrors.sh | grep Modified | awk '{match($0, /20/); print substr($0, RSTART)}' | head -n 1)
#sh_v_new=$(curl -s https://gitee.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh | grep Modified | sed 's/.*\(20.*\)/\1/')
#sh_v=$(cat $sh_shell/ChangeMirrors.sh | grep Modified | sed 's/.*\(20.*\)/\1/')

if [ "$sh_v" = "$sh_v_new" ]; then
	echo -e "${GREEN}无需更新${YELLOW} 更新日期：$sh_v${PLAIN}"
	cd $sh_shell
	bash ChangeMirrors.sh
	self-menu
else
	echo "发现新版本！"
	echo -e "当前版本${YELLOW} 更新日期：$sh_v${PLAIN}"
	echo -e "最新版本${BLUE} 更新日期：$sh_v_new${PLAIN}"
	echo "------------------------"
	cd $sh_shell
	# 设置源文件路径和目标目录
	source_file="ChangeMirrors.sh"
	##destination_dir="~"
	# 获取当前日期和时间，并格式化为YYYYMMDD_HHMMSS
	timestamp=$(date +"%Y%m%d_%H%M%S")
	# 提取源文件的扩展名（如果有的话）
	extension="${source_file##*.}"
	# 构建带有时间戳的目标文件名
	destination_file="bak-$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	##destination_file="${destination_dir}$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	# 备份文件并指定新的文件名
	cp "${source_file}" "${destination_file}"
	echo -e "旧版本文件备份完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
	curl -sS -O https://gitee.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh && chmod +x ./ChangeMirrors.sh
	sed -i "s|&& clear| |g" ./ChangeMirrors.sh	
	echo -e "${GREEN}已经更新${YELLOW} 更新日期：$sh_v_new${PLAIN}"
	bash ChangeMirrors.sh
fi
self-menu
}
#设置系统源[国外主机]
2_ChangeMirrors_abroad() {
echo ""
echo ""
echo ""
echo ""
sh_shell="/root/shell"
cd $sh_shell && touch ChangeMirrors.sh
sh_v_new=$(curl -s https://raw.githubusercontent.com/SuperManito/LinuxMirrors/main/ChangeMirrors.sh | grep Modified | awk '{match($0, /20/); print substr($0, RSTART)}' | head -n 1)
sh_v=$(cat $sh_shell/ChangeMirrors.sh | grep Modified | awk '{match($0, /20/); print substr($0, RSTART)}' | head -n 1)
#sh_v_new=$(curl -s https://raw.githubusercontent.com/SuperManito/LinuxMirrors/main/ChangeMirrors.sh | grep Modified | sed 's/.*\(20.*\)/\1/')
#sh_v=$(cat $sh_shell/ChangeMirrors.sh | grep Modified | sed 's/.*\(20.*\)/\1/')


if [ "$sh_v" = "$sh_v_new" ]; then
	echo -e "${GREEN}无需更新${YELLOW} 更新日期：$sh_v${PLAIN}"
	cd $sh_shell
	XuanZhi_source
else
	echo "发现新版本！"
	echo -e "当前版本${YELLOW} 更新日期：$sh_v${PLAIN}"
	echo -e "最新版本${BLUE} 更新日期：$sh_v_new${PLAIN}"
	echo "------------------------"
	cd $sh_shell
	# 设置源文件路径和目标目录
	source_file="ChangeMirrors.sh"
	##destination_dir="~"
	# 获取当前日期和时间，并格式化为YYYYMMDD_HHMMSS
	timestamp=$(date +"%Y%m%d_%H%M%S")
	# 提取源文件的扩展名（如果有的话）
	extension="${source_file##*.}"
	# 构建带有时间戳的目标文件名
	destination_file="bak-$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	##destination_file="${destination_dir}$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	# 备份文件并指定新的文件名
	cp "${source_file}" "${destination_file}"
	echo -e "旧版本文件备份完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
	curl -sS -O https://raw.githubusercontent.com/SuperManito/LinuxMirrors/main/ChangeMirrors.sh && chmod +x ChangeMirrors.sh
	sed -i "s|&& clear| |g" ChangeMirrors.sh	
	echo -e "${GREEN}已经更新${YELLOW} 更新日期：$sh_v_new${PLAIN}"
	XuanZhi_source
fi
self-menu
}
#安装docker环境
3_Docker_Installation() {
echo ""
echo ""
echo ""
echo ""
sh_shell="/root/shell"
cd $sh_shell && touch DockerInstallation.sh
sh_v_new=$(curl -s https://gitee.com/SuperManito/LinuxMirrors/raw/main/DockerInstallation.sh | grep Modified | awk '{match($0, /20/); print substr($0, RSTART)}' | head -n 1)
sh_v=$(cat $sh_shell/DockerInstallation.sh | grep Modified | awk '{match($0, /20/); print substr($0, RSTART)}' | head -n 1)
#sh_v_new=$(curl -s https://gitee.com/SuperManito/LinuxMirrors/raw/main/DockerInstallation.sh | grep Modified | sed 's/.*\(20.*\)/\1/')
#sh_v=$(cat $sh_shell/DockerInstallation.sh | grep Modified | sed 's/.*\(20.*\)/\1/')

if [ "$sh_v" = "$sh_v_new" ]; then
	echo -e "${GREEN}无需更新${YELLOW} 更新日期：$sh_v${PLAIN}"
	cd $sh_shell
	bash DockerInstallation.sh
	self-menu
else
	echo "发现新版本！"
	echo -e "当前版本${YELLOW} 更新日期：$sh_v${PLAIN}"
	echo -e "最新版本${BLUE} 更新日期：$sh_v_new${PLAIN}"
	echo "------------------------"
	cd $sh_shell
	# 设置源文件路径和目标目录
	source_file="DockerInstallation.sh"
	##destination_dir="~"
	# 获取当前日期和时间，并格式化为YYYYMMDD_HHMMSS
	timestamp=$(date +"%Y%m%d_%H%M%S")
	# 提取源文件的扩展名（如果有的话）
	extension="${source_file##*.}"
	# 构建带有时间戳的目标文件名
	destination_file="bak-$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	##destination_file="${destination_dir}$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	# 备份文件并指定新的文件名
	cp "${source_file}" "${destination_file}"
	echo -e "旧版本文件备份完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
	curl -sS -O https://gitee.com/SuperManito/LinuxMirrors/raw/main/DockerInstallation.sh && chmod +x ./DockerInstallation.sh
	sed -i "s|&& clear| |g" ./DockerInstallation.sh	
	echo -e "${GREEN}已经更新${YELLOW} 更新日期：$sh_v_new${PLAIN}"
	bash DockerInstallation.sh
fi
self-menu
}
#更新LDNMP建站脚本
4_up_kejilion() {
echo ""
echo ""
echo ""
echo ""
sh_shell="/root/shell"
cd $sh_shell && touch kejilion.sh && chmod +x kejilion.sh
sh_v_new=$(curl -s https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)
sh_v=$(cat $sh_shell/kejilion.sh | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)

if [ "$sh_v" = "$sh_v_new" ]; then
	echo -e "${GREEN}无需更新${YELLOW} version：$sh_v${PLAIN}"
	cd $sh_shell
	#chmod +x kejilion.sh
	ln -sf ~/shell/kejilion.sh /usr/local/bin/k
	bash kejilion.sh
	self-menu
else
	echo "更新日志"
	echo "------------------------"
	echo "全部日志: https://raw.githubusercontent.com/kejilion/sh/main/kejilion_sh_log.txt"
	echo "------------------------"
	curl -s https://raw.githubusercontent.com/kejilion/sh/main/kejilion_sh_log.txt | tail -n 35
	echo ""
	echo ""
	echo "发现新版本！"
	echo -e "当前版本${YELLOW} version：$sh_v${PLAIN}"
	echo -e "最新版本${BLUE} version：$sh_v_new${PLAIN}"
	echo "------------------------"
	cd $sh_shell
	# 设置源文件路径和目标目录
	source_file="kejilion.sh"
	##destination_dir="~"
	# 获取当前日期和时间，并格式化为YYYYMMDD_HHMMSS
	timestamp=$(date +"%Y%m%d_%H%M%S")
	# 提取源文件的扩展名（如果有的话）
	extension="${source_file##*.}"
	# 构建带有时间戳的目标文件名
	destination_file="bak-$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	##destination_file="${destination_dir}$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	# 备份文件并指定新的文件名
	cp "${source_file}" "${destination_file}"
	echo -e "旧版本文件备份完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
	curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh
	echo ""
	sed -i "s|nginx_status()|nginx__status()|g" kejilion.sh
	sed -i "s|nginx_status|##nginx_status|g" kejilion.sh 
	sed -i "s|install_ssltls() |install__ssltls() |g" kejilion.sh
	sed -i "s|install_ssltls|##install_ssltls|g" kejilion.sh 
	sed -i "s|iptables_open()|iptables__open()|g" kejilion.sh
	sed -i "s|iptables_open|##iptables_open|g" kejilion.sh
	sed -i "s|install_certbot()|install__certbot()|g" kejilion.sh
	sed -i "s|install_certbot|##install_certbot|g" kejilion.sh
	echo ""
	sed -i "s|clear|###clear|g" kejilion.sh
	sed -i "s|rm /home/web/certs|##rm /home/web/certs|g" kejilion.sh
	sed -i "s|web/mysql web/certs|web/mysql|g" kejilion.sh
	echo ""
	sed -i "s|base64 16|base64 18|g" kejilion.sh
	sed -i "s|base64 8|base64 9|g" kejilion.sh
	echo ""
	sed -i "s|kejilion/docker/main/LNMP-docker-compose-10.yml|twcoin/linux/main/LNMP-docker-compose-10.yml|g" kejilion.sh
	echo -e "${GREEN}已经更新${YELLOW} version：$sh_v_new${PLAIN}"
	ln -sf ~/shell/kejilion.sh /usr/local/bin/k
	bash kejilion.sh
fi
self-menu
}
#在 Debian Ubuntu 中安装v2raya
5_install_v2raya() {
echo ""
echo ""
echo ""
echo ""
wget -qO - https://apt.v2raya.org/key/public-key.asc | tee /etc/apt/keyrings/v2raya.asc
echo -e "${GREEN}添加公钥完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
echo "deb [signed-by=/etc/apt/keyrings/v2raya.asc] https://apt.v2raya.org/ v2raya main" | tee /etc/apt/sources.list.d/v2raya.list
echo -e "${GREEN}添加软件源完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
apt update
apt install v2raya xray
systemctl start v2raya.service
systemctl enable v2raya.service
echo -e "${GREEN}v2raya安装完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
self-menu
}
#更新GEO文件
6_up_geo_data() {
echo ""
echo ""
echo ""
echo ""
mkdir -p /usr/share/xray /usr/share/v2ray
#xray geo路径
geodata_xray="/usr/share/xray"
#v2ray geo路径
geodata_v2ray="/usr/share/v2ray"
#geo临时路径
tmp_folder="/tmp"

cd $tmp_folder
echo -e "${GREEN}>>> change directory...${PLAIN}"

GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOIP_URL_CN="https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat"
#echo -e "${GREEN}>>> downloading and overwrite geoip.dat files...${PLAIN}"
echo -e "${GREEN}>>> downloading geoip.dat files...${PLAIN}"
curl -L -O $GEOIP_URL
#curl -L -O $GEOIP_URL_CN

GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
GEOSITE_URL_CN="https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat"
echo -e "${GREEN}>>> downloading geosite.dat files...${PLAIN}"
curl -L -O $GEOSITE_URL
#curl -L -O $GEOSITE_URL_CN

echo -e "${GREEN}>>> delete old dat files...${PLAIN}"


cp -r $tmp_folder/geoip.dat $geodata_xray/geoip.dat
cp -r $tmp_folder/geosite.dat $geodata_xray/geosite.dat

cp -r $tmp_folder/geoip.dat $geodata_v2ray/geoip.dat
cp -r $tmp_folder/geosite.dat $geodata_v2ray/geosite.dat


chmod 755 $geodata_xray/geo*.dat
chmod 755 $geodata_v2ray/geo*.dat

echo -e "${GREEN}>>> file information...${PLAIN}"
ls -l $geodata_xray/*
du -sh $geodata_xray/*
#systemctl restart v2raya.service
#systemctl status v2raya.service
#/etc/init.d/v2raya restart
#/etc/init.d/v2raya status
echo -e "${GREEN}geo文件更新完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
self-menu
}

7_1_install_certbot() {

    if command -v yum &>/dev/null; then
        install epel-release certbot
    else
        install certbot
    fi

    # 切换到一个一致的目录
    cd ~/shell || exit

    # 下载并使脚本可执行
    curl -O https://raw.githubusercontent.com/kejilion/sh/main/auto_cert_renewal.sh
    chmod +x auto_cert_renewal.sh

    # 设置定时任务字符串
    cron_job="0 0 * * * ~/shell/auto_cert_renewal.sh"

    # 检查是否存在相同的定时任务
    existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

    # 如果不存在，则添加定时任务
    if [ -z "$existing_cron" ]; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo "续签任务已添加"
    else
        echo "续签任务已存在，无需添加"
    fi
self-menu
}

7_install_ssltls() {
      docker stop nginx > /dev/null 2>&1
      cd ~

      certbot_version=$(certbot --version 2>&1 | grep -oP "\d+\.\d+\.\d+")

      version_ge() {
          [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]
      }

      if version_ge "$certbot_version" "1.10.0"; then
          certbot certonly --standalone -d $yuming --email your@email.com --agree-tos --no-eff-email --force-renewal --key-type ecdsa
      else
          certbot certonly --standalone -d $yuming --email your@email.com --agree-tos --no-eff-email --force-renewal
      fi

      cp /etc/letsencrypt/live/$yuming/fullchain.pem /home/web/certs/${yuming}_cert.pem
      cp /etc/letsencrypt/live/$yuming/privkey.pem /home/web/certs/${yuming}_key.pem
      docker start nginx > /dev/null 2>&1
self-menu
}
#自用 docker-compose.yml下载及certs文件夹设置
8_docker_compose_and_certs() {
echo ""
echo ""
echo ""
echo ""
link_app_certs=$(file /home/docker/certs | grep -o link)
link_web_certs=$(file /home/web/certs | grep -o link)
folder_certs=$(file /root/certs | grep -o link)
shell_docker_compose="/home/docker"
if [ "$folder_certs" = "$link_web_certs" ]; then
   rm -fr /home/web/cert*
   ln -s /root/certs /home/web/certs
   echo -e "${GREEN}>>> set link_web_certs...$RED>>>OK${PLAIN}"
   8_docker_compose_and_certs
elif [ "$folder_certs" = "$link_app_certs" ]; then
    rm -fr /home/docker/cert*
	ln -s /root/certs /home/docker/certs
	echo -e "${GREEN}>>> set link_app_certs...$RED>>>OK${PLAIN}"
	8_docker_compose_and_certs
else
echo -e ""
fi


cd $shell_docker_compose && touch 3x-ui.yml
sh_v_new=$(curl -s https://raw.githubusercontent.com/twcoin/linux/main/3x-ui/3x-ui.yml | grep "#UPDATE" | awk '{match($0, /20/); print substr($0, RSTART)}' | head -n 1)
sh_v=$(cat $shell_docker_compose/3x-ui.yml | grep "#UPDATE" | awk '{match($0, /20/); print substr($0, RSTART)}' | head -n 1)
#sh_v_new=$(curl -s https://raw.githubusercontent.com/twcoin/linux/main/3x-ui/3x-ui.yml | grep "#UPDATE" | sed 's/.*\(20.*\)/\1/')
#sh_v=$(cat $shell_docker_compose/3x-ui.yml | grep "#UPDATE" | sed 's/.*\(20.*\)/\1/')

if [ "$sh_v" = "$sh_v_new" ]; then
	echo -e "${GREEN}无需更新${YELLOW} 更新日期：$sh_v${PLAIN}"
	self-menu
else
	echo "发现新版本！"
	echo -e "当前版本${YELLOW} 更新日期：$sh_v${PLAIN}"
	echo -e "最新版本${BLUE} 更新日期：$sh_v_new${PLAIN}"
	echo "------------------------"
	cd $shell_docker_compose
	# 设置源文件路径和目标目录
	source_file="3x-ui.yml"
	##destination_dir="~"
	# 获取当前日期和时间，并格式化为YYYYMMDD_HHMMSS
	timestamp=$(date +"%Y%m%d_%H%M%S")
	# 提取源文件的扩展名（如果有的话）
	extension="${source_file##*.}"
	# 构建带有时间戳的目标文件名
	destination_file="bak-$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	##destination_file="${destination_dir}$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	# 备份文件并指定新的文件名
	cp "${source_file}" "${destination_file}"
	echo -e "旧版本文件备份完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
	curl -sS -O https://raw.githubusercontent.com/twcoin/linux/main/3x-ui/3x-ui.yml && chmod +x ./3x-ui.yml
	echo -e "${GREEN}已经更新${YELLOW} 更新日期：$sh_v_new${PLAIN}"
fi
self-menu
}
#解决 Debian Ubuntu 系统中tab补全问题
9_install_bash-completion() {
echo ""
echo ""
echo ""
echo ""
apt update
apt install bash-completion
echo -e "${GREEN}软件安装完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
printf "if [ -f /etc/bash_completion ]; then\n. /etc/bash_completion\nfi\n" >> ~/.bashrc
sleep 1
source ~/.bashrc
sleep 1
source ~/.bashrc
echo -e "${GREEN}设置完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
self-menu
}
#在 openwrt 中安装v2raya
10_ainstall_v2raya_openwrt() {
echo ""
echo ""
echo ""
echo ""
wget https://downloads.sourceforge.net/project/v2raya/openwrt/v2raya.pub -O /etc/opkg/keys/94cc2a834fb0aa03
echo -e "${GREEN}Add v2rayA usign key...${PLAIN}"
echo "src/gz v2raya https://downloads.sourceforge.net/project/v2raya/openwrt/$(. /etc/openwrt_release && echo "$DISTRIB_ARCH")" | tee -a "/etc/opkg/customfeeds.conf"
echo -e "${GREEN}Import v2rayA feed...${PLAIN}"
opkg install v2raya
opkg install kmod-nft-tproxy
#建议使用xray内核，v2ray内核使用tproxy有小问题
opkg install xray-core
opkg install luci-app-v2raya
/etc/init.d/v2raya start
self-menu
}
#更新脚本
12_update_acme_sh() {
echo ""
echo ""
echo ""
echo ""
cd ~ && touch acme.sh
ln -sf ~/acme.sh /usr/local/bin/zs

githubusercontent_URL="https://raw.githubusercontent.com/twcoin/linux/main/sh/acme.sh"
github_URL="https://github.com/twcoin/linux/releases/latest/acme.sh"
gitee_URL="https://gitee.com/foxfix/linux/raw/main/sh/acme.sh"

sh_dir="/root"

sh_v_new=$(curl -s $githubusercontent_URL | grep "Update-Time" | awk '{match($0, /20/); print substr($0, RSTART)}' | head -n 1)
sh_v=$(cat $sh_dir/acme.sh | grep "Update-Time" | awk '{match($0, /20/); print substr($0, RSTART)}' | head -n 1)
#sh_v_new=$(curl -s $githubusercontent_URL | grep "Update-Time" | sed 's/.*\(20.*\)/\1/')
#sh_v=$(cat $sh_dir/acme.sh | grep "Update-Time" | sed 's/.*\(20.*\)/\1/')

if [ "$sh_v" = "$sh_v_new" ]; then
	echo -e "${GREEN}无需更新${YELLOW} 更新日期：$sh_v${PLAIN}"
	cd $sh_dir
	self-menu
else
	echo "发现新版本！"
	echo -e "当前版本${YELLOW} 更新日期：$sh_v${PLAIN}"
	echo -e "最新版本${BLUE} 更新日期：$sh_v_new${PLAIN}"
	echo "------------------------"
	cd $sh_dir
	# 设置源文件路径和目标目录
	source_file="acme.sh"
	##destination_dir="~"
	# 获取当前日期和时间，并格式化为YYYYMMDD_HHMMSS
	timestamp=$(date +"%Y%m%d_%H%M%S")
	# 提取源文件的扩展名（如果有的话）
	extension="${source_file##*.}"
	# 构建带有时间戳的目标文件名
	destination_file="bak-$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	##destination_file="${destination_dir}$(basename "${source_file}" ".${extension}")_${timestamp}.${extension}"
	# 备份文件并指定新的文件名
	cp "${source_file}" "${destination_file}"
	echo -e "旧版本文件备份完成${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
	curl -L -O $githubusercontent_URL && chmod +x acme.sh
	echo -e "${GREEN}已经更新${YELLOW} 更新日期：$sh_v_new${PLAIN}"
fi
self-menu
}
#备份数据
13_backup_to_local() {
backup_data_dir="/home"
backup_certs_dir="/root"
backup_dir="/root/shell"
compose_container_dir="/home/web"
echo ""
echo -e "${GREEN}>>> Stop the container ... ${PLAIN}[${YELLOW}Please wait ... ${PLAIN}]${PLAIN}"
docker compose -f $compose_container_dir/docker-compose.yml stop
echo -e "${GREEN}>>> Stop the container ... ${PLAIN}[${RED}Finish${PLAIN}]${PLAIN}"
echo ""
#创建对应目录web、docker、serts文件夹备份
echo -e "${GREEN}>>> Create tar archive of the backup directory ... ${PLAIN}[${YELLOW}Please wait ... ${PLAIN}]${PLAIN}"
cd $backup_data_dir && tar czvf web_$(date +"%Y%m%d%H%M%S").tar.gz web >/dev/null 2>&1
cd $backup_data_dir && tar czvf docker_$(date +"%Y%m%d%H%M%S").tar.gz docker >/dev/null 2>&1
cd $backup_certs_dir && tar czvf certs_$(date +"%Y%m%d%H%M%S").tar.gz certs >/dev/null 2>&1
cd $backup_certs_dir && tar czvf .acme.sh$(date +"%Y%m%d%H%M%S").tar.gz .acme.sh >/dev/null 2>&1
mv $backup_data_dir/*.gz $backup_dir
mv $backup_certs_dir/*.gz $backup_dir
mv $backup_certs_dir/.*.gz $backup_dir
echo -e "${GREEN}>>> Create tar archive of the backup directory ... ${PLAIN}[${RED}Finish${PLAIN}]${PLAIN}"
echo ""
echo -e "${GREEN}>>> Start the container ... ${PLAIN}[${YELLOW}Please wait ... ${PLAIN}]${PLAIN}"
docker compose -f $compose_container_dir/docker-compose.yml start
echo -e "${GREEN}>>> Start the container ... ${PLAIN}[${RED}Finish${PLAIN}]${PLAIN}"
echo ""
#删除web、docker、serts多余备份
cd $backup_dir && ls -t $backup_dir/web*.tar.gz | tail -n +6 | xargs -I {} rm {}
cd $backup_dir && ls -t $backup_dir/certs*.tar.gz | tail -n +6 | xargs -I {} rm {}
cd $backup_dir && ls -t $backup_dir/docker*.tar.gz | tail -n +6 | xargs -I {} rm {}
cd $backup_dir && ls -t $backup_dir/.acme*.tar.gz | tail -n +6 | xargs -I {} rm {}
echo -e "${GREEN}>>> Delete tar archive of old backup directory ... ${PLAIN}[${RED}Keep only 5 tar archives${PLAIN}]${PLAIN} [${RED}Finish${PLAIN}]${PLAIN}"
self-menu
}
#还原数据
14_reload_from_local() {
backup_data_dir="/home"
backup_certs_dir="/root"
backup_dir="/root/shell"
compose_container_dir="/home/web"
echo ""
echo -e "${GREEN}>>> Stop the container ... ${PLAIN}[${YELLOW}Please wait ... ${PLAIN}]${PLAIN}"
docker compose -f $compose_container_dir/docker-compose.yml stop
echo -e "${GREEN}>>> Stop the container ... ${PLAIN}[${RED}Finish${PLAIN}]${PLAIN}"
echo ""
echo -e "${GREEN}>>> Reload tar archive of the backup directory ... ${PLAIN}[${YELLOW}Please wait ... ${PLAIN}]${PLAIN}"
#提取文件及文件名
#file_cert_gz=$(ls -t $backup_dir/*.tar.gz | grep "certs" | awk '{match($0, /cert/); print substr($0, RSTART)}' | head -n 1)
#file_cert_sh_gz=$(ls -t $backup_dir/.*.tar.gz | grep "acme" | awk '{match($0, /.acme/); print substr($0, RSTART)}' | head -n 1)
#file_web_gz=$(ls -t $backup_dir/*.tar.gz  | grep "web" | awk '{match($0, /web/); print substr($0, RSTART)}' | head -n 1)
#file_docker_gz=$(ls -t $backup_dir/*.tar.gz | grep "docker" | awk '{match($0, /docker/); print substr($0, RSTART)}' | head -n 1)
#提取文件路径与文件及文件名
file_cert_gz=$(ls -t $backup_dir/*.tar.gz | grep "certs" | head -n 1)
file_cert_sh_gz=$(ls -t $backup_dir/.*.tar.gz | grep "acme" | head -n 1)
file_web_gz=$(ls -t $backup_dir/*.tar.gz  | grep "web" | head -n 1)
file_docker_gz=$(ls -t $backup_dir/*.tar.gz | grep "docker" | head -n 1)

cp $file_cert_gz $backup_certs_dir
cp $file_cert_sh_gz $backup_certs_dir
cp $file_web_gz $backup_data_dir
cp $file_docker_gz $backup_data_dir

cd $backup_certs_dir && ls *.tar.gz | grep "certs" | xargs -I {} tar -vxzf {}
cd $backup_certs_dir && ls .*.tar.gz | grep "acme" | xargs -I {} tar -vxzf {}
cd $backup_data_dir && ls *.tar.gz | grep "web" | xargs -I {} tar -vxzf {}
cd $backup_data_dir && ls *.tar.gz | grep "docker" | xargs -I {} tar -vxzf {}
cd $backup_data_dir && rm -fr *.tar.gz
cd $backup_certs_dir && rm -fr *.tar.gz && rm -fr .*.tar.gz
echo -e "${GREEN}>>> Reload tar archive of the backup directory ... ${PLAIN}[${RED}Finish${PLAIN}]${PLAIN}"
echo ""
echo -e "${GREEN}>>> Start the container ... ${PLAIN}[${YELLOW}Please wait ... ${PLAIN}]${PLAIN}"
docker compose -f $compose_container_dir/docker-compose.yml start
echo -e "${GREEN}>>> Start the container ... ${PLAIN}[${RED}Finish${PLAIN}]${PLAIN}"
self-menu
}

#acme脚本菜单
acme-menu() {
	echo ""
	echo ""
	echo ""
	echo ""
	echo -e "${GREEN}>>>${YELLOW}Loading script ... ${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
	echo "##################################################################"
	echo -e "#			${RED}Acme  证书一键申请脚本${PLAIN}			 #"
	echo -e "# ${GREEN}作者${PLAIN}: 爱分享的小企鹅						 #"
	echo -e "# ${GREEN}网站${PLAIN}: https://www.youtube.com/channel/UCLd2LDzFPFoUnuQsP8y1wRA #"
	echo "##################################################################"
	echo ""
	echo -e " ${GREEN}1.${PLAIN} 安装 Acme.sh 域名证书申请脚本${PLAIN}"
	echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 Acme.sh 域名证书申请脚本${PLAIN}"
	echo " -------------"
	echo -e " ${GREEN}3.${PLAIN} 申请单域名证书 ${YELLOW}(80端口申请)${PLAIN}"
	echo -e " ${GREEN}4.${PLAIN} 申请单域名证书 ${YELLOW}(CF API申请)${PLAIN} ${GREEN}(无需解析)${PLAIN} ${RED}(不支持freenom域名)${PLAIN}"
	echo -e " ${GREEN}5.${PLAIN} 申请泛域名证书 ${YELLOW}(CF API申请)${PLAIN} ${GREEN}(无需解析)${PLAIN} ${RED}(不支持freenom域名)${PLAIN}"
	echo " -------------"
	echo -e " ${GREEN}6.${PLAIN} 查看已申请的证书"
	echo -e " ${GREEN}7.${PLAIN} 撤销并删除已申请的证书"
	echo -e " ${GREEN}8.${PLAIN} 手动续期已申请的证书"
	echo -e " ${GREEN}9.${PLAIN} 切换证书颁发机构"
	echo " -------------"
	echo -e " ${GREEN}0.${PLAIN} 退出脚本"
	echo ""
	read -rp "请输入选项 [0-9]: " NumberInput
	case "$NumberInput" in
		1) install_acme ;;
		2) uninstall ;;
		3) acme_standalone ;;
		4) acme_cfapiTLD ;;
		5) acme_cfapiNTLD ;;
		6) view_cert ;;
		7) revoke_cert ;;
		8) renew_cert ;;
		9) switch_provider ;;
		11) bakup_cert ;;
		*) self-menu ;;
	esac
}
#主菜单
self-menu() {
	echo ""
	echo ""
	echo ""
	echo ""
	echo -e "${GREEN}>>>${YELLOW}Loading script ... ${PLAIN}[${RED}ok${PLAIN}]${PLAIN}"
	echo "#################################################"
	echo -e "# ${RED}个人大杂烩脚本${PLAIN}				#"
	echo -e "# ${GREEN}作者${PLAIN}: Foxfix${PLAIN}					#"
	echo -e "# ${GREEN}网站${PLAIN}: 暂时没有${PLAIN}				#"
	echo "#################################################"
	echo ""
	echo -e " ${GREEN}1.${PLAIN} 设置系统软件源${PLAIN}${GREEN} 作者${PLAIN}: [SuperManito]${PLAIN}"
	echo -e " ${GREEN}2.${PLAIN} 设置系统软件源[海外]${PLAIN}${GREEN} 作者${PLAIN}: [SuperManito]${PLAIN}"
	echo -e " ${GREEN}3.${PLAIN} 安装docker环境${PLAIN}${GREEN} 作者${PLAIN}: [SuperManito]${PLAIN}"
	echo -e " ${GREEN}4.${PLAIN} ${RED}更新LDNMP建站脚本${GREEN} 作者${PLAIN}: [科技lion]${PLAIN}"
	echo " -------------"
	echo -e " ${GREEN}5.${PLAIN} 在 ${RED}Debian${PLAIN} ${RED}Ubuntu${PLAIN} 中安装 v2raya${PLAIN}"
	echo -e " ${GREEN}6.${PLAIN} 更新GEO文件${PLAIN}"
	echo -e " ${GREEN}7.${PLAIN} 证书一键申${PLAIN}"
	echo " -------------"
	echo -e " ${GREEN}8.${PLAIN} 自用 ${RED}docker compose ${PLAIN}配置文件下载及${RED}certs${PLAIN}文件夹设置${PLAIN}"
	echo -e " ${GREEN}9.${PLAIN} 解决 ${RED}Debian${PLAIN} ${RED}Ubuntu${PLAIN} 命令补全问题${PLAIN}"
	echo " -------------"
	echo -e " ${GREEN}10.${PLAIN}在 ${RED}openwrt${PLAIN} 中安装v2raya${PLAIN}"
	echo -e " ${GREEN}11.${PLAIN}Acme证书一键申请脚本${GREEN} 作者${PLAIN}: [爱分享的小企鹅]${PLAIN}"
	echo " -------------"
	echo -e " ${GREEN}12.${PLAIN}更新脚本${PLAIN}"
	echo -e " ${GREEN}13.${PLAIN}备份数据${PLAIN}${RED} 谨慎使用${PLAIN}"
	echo -e " ${GREEN}14.${PLAIN}还原数据${PLAIN}${RED} 谨慎使用${PLAIN}"
	echo " -------------"
	echo -e " ${GREEN}0.${PLAIN} 退出脚本${PLAIN}"
	echo ""
	read -rp "请输入选项 [0-14]: " NumberInput
	case "$NumberInput" in
		1) 1_Change_Mirrors ;;
		2) 2_ChangeMirrors_abroad ;;
		3) 3_Docker_Installation ;;
		4) 4_up_kejilion ;;
		5) 5_install_v2raya ;;
		6) 6_up_geo_data ;;
		6) 7_install_ssltls ;;
		8) 8_docker_compose_and_certs ;;
		9) 9_install_bash-completion ;;
		10) 10_ainstall_v2raya_openwrt ;;
		11) acme-menu ;;
		12) 12_update_acme_sh ;;
		13) 13_backup_to_local ;;
		14) 14_reload_from_local ;;
		*) exit 1 ;;
	esac
}
XuanZhi_source() {
	echo -e " ${GREEN}1.${PLAIN} 设置${RED}官方${PLAIN}软件源${PLAIN}"
	echo -e " ${GREEN}2.${PLAIN} 设置${RED}海外${PLAIN}软件源${PLAIN}"
	read -rp "请输入选项 [1-2]: " NumberInput
	case "$NumberInput" in
		1) use_official_source ;;
		2) use_abroad ;;
		*) 2_ChangeMirrors_abroad ;;
	esac
}

#官方软件源
use_official_source() {
bash ChangeMirrors.sh --use-official-source
self-menu
}
#海外软件源
use_abroad() {
bash ChangeMirrors.sh --abroad
self-menu
}
#clear
8_docker_compose_and_certs
