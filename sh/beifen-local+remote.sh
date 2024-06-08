#!/bin/bash

# Create a tar archive of the web directory
# 创建目录/home/web的备份文件
cd /home/ && tar czvf web_$(date +"%Y%m%d%H%M%S").tar.gz web
# 创建目录/home/certs的备份文件
cd /home/ && tar czvf certs_$(date +"%Y%m%d%H%M%S").tar.gz certs
# 创建目录/home/3x-ui的备份文件
cd /home/ && tar czvf 3x-ui_$(date +"%Y%m%d%H%M%S").tar.gz 3x-ui
# 创建目录/root的备份文件
cd / && tar czvf /home/root_$(date +"%Y%m%d%H%M%S").tar.gz root
echo "备份文件创建完成"
echo "备份文件备份至远端设备中……"
# Transfer the tar archive to another VPS
cd /home/ && ls -t /home/web*.tar.gz | head -1 | xargs -I {} sshpass -p PASSWORD scp -o StrictHostKeyChecking=no -P 22 {} root@IP:/home/
echo "web备份文件远程备份完成"
cd /home/ && ls -t /home/certs*.tar.gz | head -1 | xargs -I {} sshpass -p PASSWORD scp -o StrictHostKeyChecking=no -P 22 {} root@IP:/home/
echo "certs备份文件远程备份完成"
cd /home/ && ls -t /home/3x-ui*.tar.gz | head -1 | xargs -I {} sshpass -p PASSWORD scp -o StrictHostKeyChecking=no -P 22 {} root@IP:/home/
echo "3x-ui备份文件远程备份完成"
cd /home/ && ls -t /home/root*.tar.gz | head -1 | xargs -I {} sshpass -p PASSWORD scp -o StrictHostKeyChecking=no -P 22 {} root@IP:/home/
echo "root备份文件远程备份完成"

# Keep only 5 tar archives and delete the rest
# 删除本地备份老旧文件
cd /home/ && ls -t /home/web*.tar.gz | tail -n +4 | xargs -I {} rm {}
cd /home/ && ls -t /home/certs*.tar.gz | tail -n +4 | xargs -I {} rm {}
cd /home/ && ls -t /home/3x-ui*.tar.gz | tail -n +4 | xargs -I {} rm {}
cd /home/ && ls -t /home/root*.tar.gz | tail -n +4 | xargs -I {} rm {}
echo "删除本地备份老旧文件完成"
