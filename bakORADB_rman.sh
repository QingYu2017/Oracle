#!/bin/bash 
#Auth:Qing.Yu
#Mail:1753330141@qq.com
# Ver:V1.0
#Date:2018-08-10
#使用rman方式进行备份，备份结束后文件压缩（zip）、删除备份（保留zip）、删除rman备份集信息
#Ansible 测试脚本工作
#ansible oradb -S -R oracle -m script -a  "/root/Ansible_Playbook/Script/bakOAPROD8_rman.sh" -vv

#加载环境变量，非login方式（ansible）默认不加载环境变量，会造成调用oracle的程序如rman出错
source ~/.bash_profile
#定义路径和日期
d=`/bin/date +%Y-%m-%d`
p=/media/ORADB/bakORADB_rman
#创建rman备份
echo "backup as compressed backupset database format'$p/oraBAK_%d_%I_%Y-%M-%D_%U';"|rman target sys/xxxxxxxx@OAPROD8
#将备份压缩为指定日期标记的zip文件
zip -r $p/rman_bak_$d.zip $p -P xxxxxxxx
#删除rman备份目录下的非zip文件
ls $p |grep -v "zip" |sed "s:^:$p/:"| xargs rm 
#清理rman的过期备份，先标记expired再删除最后列表确认
echo "CROSSCHECK BACKUP;delete noprompt expired backup;list backup;" |rman target sys/xxxxxxxx@OAPROD8
