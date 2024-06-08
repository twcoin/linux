#!/bin/bash
# 恢复本地备份
cd /home/ && ls -t /home/web*.tar.gz | head -1 | xargs -I {} tar -xzf {}
cd /home/ && ls -t /home/certs*.tar.gz | head -1 | xargs -I {} tar -xzf {}
cd /home/ && ls -t /home/3x-ui*.tar.gz | head -1 | xargs -I {} tar -xzf {}
cd / && ls -t /home/root*.tar.gz | head -1 | xargs -I {} tar -xzf {}
