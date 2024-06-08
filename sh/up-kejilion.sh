#!/bin/bash
cd ~
chmod +x up-kejilion.sh
touch kejilion.sh
rm -fr /usr/local/bin/k

forced_up() { #强制更换脚本并替换
    echo "强制更新请输入F"
    read -p "确定更新脚本吗？(F/N): " choice
    case "$choice" in
        [Nn])
            echo "已取消"
            cp -r ~/kejilion.sh /usr/local/bin/k
            ;;
        [Ff])
            # 下载文件并替换
            curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh
            echo -e "${lv}脚本已更新到最新版本${huang}v$sh_v_new${bai}"
            sed -i "s|docker stop nginx >|##docker stop nginx >|g" ~/kejilion.sh
            sed -i "s|docker start nginx >|##docker start nginx >|g" ~/kejilion.sh
            sed -i "s|certbot certonly|##certbot certonly|g" ~/kejilion.sh
            sed -i "s|fullchain.pem|cert.crt|g" ~/kejilion.sh
            sed -i "s|privkey.pem|private.key|g" ~/kejilion.sh
            sed -i "s|cp /etc/letsencrypt/live|cp -r /home/certs|g" ~/kejilion.sh
            sed -i "s|iptables -P|##iptables -P|g" ~/kejilion.sh
            sed -i "s|iptables -F|##iptables -F|g" ~/kejilion.sh
            sed -i "s|ip6tables -P|##ip6tables -P|g" ~/kejilion.sh
            sed -i "s|ip6tables -F|clear|g" ~/kejilion.sh
            sed -i "s|rm /home/web/certs|##rm /home/web/certs|g" ~/kejilion.sh
            sed -i "s|web/mysql web/certs|web/mysql|g" ~/kejilion.sh
            sed -i "s|kejilion/docker/main/LNMP-docker-compose-10.yml|twcoin/linux/main/LNMP-docker-compose-10.yml|g" ~/kejilion.sh
            cp -r ~/kejilion.sh /usr/local/bin/k
            ;;
        *)
            ;;
    esac
}

clear
echo "更新日志"
echo "------------------------"
echo "全部日志: https://raw.githubusercontent.com/kejilion/sh/main/kejilion_sh_log.txt"
echo "------------------------"
curl -s https://raw.githubusercontent.com/kejilion/sh/main/kejilion_sh_log.txt | tail -n 35
echo ""
echo ""
sh_v_new=$(curl -s https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)
sh_v=$(cat ~/kejilion.sh | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)

if [ "$sh_v" = "$sh_v_new" ]; then
    echo -e "${lv}你已经是最新版本！${huang}v$sh_v${bai}"
	forced_up
else
    echo "发现新版本！"
    echo -e "当前版本v$sh_v     最新版本${huang}v$sh_v_new${bai}"
    echo "------------------------"
    read -p "确定更新脚本吗？(Y/N): " choice
    case "$choice" in
        [Yy])
            clear
            cd ~
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
            # 复制kejilion.sh文件并指定新的文件名
            cp "${source_file}" "${destination_file}"
            # 下载文件并替换
            curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh
            echo -e "${lv}脚本已更新到最新版本${huang}v$sh_v_new${bai}"
            sed -i "s|docker stop nginx >|##docker stop nginx >|g" ~/kejilion.sh
            sed -i "s|docker start nginx >|##docker start nginx >|g" ~/kejilion.sh
            sed -i "s|certbot certonly|##certbot certonly|g" ~/kejilion.sh
            sed -i "s|fullchain.pem|cert.crt|g" ~/kejilion.sh
            sed -i "s|privkey.pem|private.key|g" ~/kejilion.sh
            sed -i "s|cp /etc/letsencrypt/live|cp -r /home/certs|g" ~/kejilion.sh
            sed -i "s|iptables -P|##iptables -P|g" ~/kejilion.sh
            sed -i "s|iptables -F|##iptables -F|g" ~/kejilion.sh
            sed -i "s|ip6tables -P|##ip6tables -P|g" ~/kejilion.sh
            sed -i "s|ip6tables -F|clear|g" ~/kejilion.sh
            sed -i "s|rm /home/web/certs|##rm /home/web/certs|g" ~/kejilion.sh
            sed -i "s|web/mysql web/certs|web/mysql|g" ~/kejilion.sh
            sed -i "s|kejilion/docker/main/LNMP-docker-compose-10.yml|twcoin/linux/main/LNMP-docker-compose-10.yml|g" ~/kejilion.sh
            cp -r ~/kejilion.sh /usr/local/bin/k
            ##break_end
            ##kejilion
            ;;
        [Nn])
            echo "已取消"
            cp -r ~/kejilion.sh /usr/local/bin/k
            ;;
        *)
            ;;
    esac
fi
