### 需求背景
投资交易系统（如恒生O32、TA等产品）、办公自动化系统（如致远、华天动力等厂商产品），支持Linux & Oracle环境部署。  
在部署专业备份系统前，可通过脚本方式，解决手工进行生产环境备份、测试环境同步时，操作繁琐而且容易存在疏漏的缺陷。
##### 建议部署堡垒机，隔离运维人员在无审计手段的情况下，直接操作服务
### 参考资料
- Linux Shell脚本攻略（第2版）；
- Oracle 11g权威指南(第2版) ；
 
### 方案设计
 
以Linux环境下的应用（tomcat）和数据库（oracle）的测试环境同步为例，同步内容包含两部分：应用系统的文件和数据库系统，生产和测试环境涉及几个动作：
1. 业务系统的数据库备份，通过expdp或rman创建备份（示例以监控、办公、业务等多套系统为例），开启归档功能的Oracle数据库，可对超期归档日志进行清除，释放日志空间；
2. 业务数据备份，如系统生成文档、关键日志、业务表单模板文件等；
3. 导出文件从生产环境导出到逻辑甚至物理隔离的测试环境；
4. 测试环境完成数据库清空、应用系统文件删除；
5. 导出文件在测试环境数据库的导入、应用系统文件的恢复；

### 示例

![执行示例](https://github.com/QingYu2017/pic/blob/master/jserver_log.gif)

备份脚本（）
```yml
#Auth:Qing.Yu
#Mail:1753330141@qq.com
# Ver:V1.5
#Date:2019-09-06
#备份OA的应用服务器数据和数据库服务器数据
#准备工作包括SSH免密码登录，NFS备份文件夹路径挂载
#ssh-copy-id -i ~/.ssh/id_rsa.pub -p 22 root@xxx.xxx.xxx.xxx

---
- hosts: zabbix
  tasks:  
  #在挂载的nfs路径中创建当天备份的路径
  - name: create local backup folder
    file:
      path: /root/bakOCH/bakFolder/{{ ansible_date_time.date }}
      state: directory

  #备份zabbix数据库
  - name: back och_zabbix data
    remote_user: root
    script: /usr/bin/mysqldump -h localhost -uzabbix -pxxxx --database zabbix |gzip -c >/root/bakOCH/bakFolder/{{ ansible_date_time.date }}/{{ ansible_date_time.date }}_ZabbixDBBak.sql.gz

  #备份och_web数据
  - name: back och_web data
    remote_user: root
    script: /usr/bin/mysqldump -hxxx.xxx.xxx.xxx -uroot -pxxxx --database huaqiao |gzip -c >/root/bakOCH/bakFolder/{{ ansible_date_time.date }}/{{ ansible_date_time.date }}_huaqiao_webDB.sql.gz

  #备份ocepay asone-frontend数据
  - name: back och_web data
    remote_user: root
    script: /usr/bin/mysqldump -hxxx.xxx.xxx.xxx -uroot -pxxxx --database asone-frontend |gzip -c >/root/bakOCH/bakFolder/{{ ansible_date_time.date }}/{{ ansible_date_time.date }}_asone-frontend_DB.sql.gz

- hosts: htoa8000V8
  remote_user: root
  tasks:
  #使用脚本备份，备份OA的APP服务器文件（压缩并设置密码）
  - name: backup htoa8000 template & trace folder
    remote_user: root
    script: /root/Ansible_Playbook/Script/bakHTOA8000V8.sh

  #列出生成的备份文件（zip格式）
  - name: list backup files
    remote_user: root
    find:
      paths: /home/bakHTOA8000V8/
      patterns: "*.zip"
    register: file_2_fetch 

  #移动文件至zbx挂载的nfs路径中的日期目录中
  - name: move backup files to file server
    remote_user: root
    fetch: 
      src: "{{ item.path }}"
      dest: /root/bakOCH/bakFolder/{{ ansible_date_time.date }}/
      flat: yes
    with_items: "{{ file_2_fetch.files }}"

  #删除应用服务器上产生的临时压缩文件
  - name: remove backup files
    remote_user: root
    file:
      path: "{{ item.path }}"    
      state: absent
    with_items: "{{ file_2_fetch.files }}"    

- hosts: oradb
  remote_user: root
  tasks:
  #执行备份脚本，dump数据文件（压缩并设置密码）
  - name: backup ORADB to dump files
    remote_user: oracle
    script: /root/Ansible_Playbook/Script/bakProc_ORADB_Remote.sh

  #归档日志处理，主要是删除7天以上的归档日志，避免长时间不维护达到磁盘上限
  - name: archivelog maintenance
    remote_user: oracle
    script: /root/Ansible_Playbook/Script/archivelog_maintenance.sh

  #列出产生的备份文件
  - name: list dump files
    remote_user: oracle
    find:
      paths: /media/ORADB/DBSoftware/app/oracle/admin/OAPROD8/dpdump/
      patterns: "*.dmp"
    register: file_2_fetch 

  #文件转移到到文件服务器上
  - name: move dump files to file server
    remote_user: oracle
    fetch: 
      src: "{{ item.path }}"
      dest: /root/bakOCH/bakFolder/{{ ansible_date_time.date }}/
      flat: yes
    with_items: "{{ file_2_fetch.files }}"
   
  #删除数据库产生的dump文件
  - name: remove dump files
    remote_user: oracle
    file:
      path: "{{ item.path }}"    
      state: absent
    with_items: "{{ file_2_fetch.files }}"

  #创建OCEPAY数据库的exp备份
  - name: create exp backup
    remote_user: oracle
    script: /root/Ansible_Playbook/Script/bakProc_ORADB_OCE.sh

  #创建HTOA8000V8数据库的rman备份，并将OCEPAY和HTOA8000V8的数据库压缩打包为zip
  - name: create rman backup
    remote_user: oracle
    script: /root/Ansible_Playbook/Script/bakOAPROD8_rman.sh

  #列出ocepay和rman产生的备份文件
  - name: list dump files
    remote_user: oracle
    find:
      paths: /media/ORADB/bakORADB_rman/
      patterns: "*.zip"
    register: rman_bak 

  #文件转移到到文件服务器上
  - name: move dump files to file server
    remote_user: oracle
    fetch: 
      src: "{{ item.path }}"
      dest: /root/bakOCH/bakFolder/{{ ansible_date_time.date }}/
      flat: yes
    with_items: "{{ rman_bak.files }}"
   
  #删除数据库产生的dump文件
  - name: remove dump files
    remote_user: oracle
    file:
      path: "{{ item.path }}"    
      state: absent
    with_items: "{{ rman_bak.files }}"

#推送微信通知信息
- hosts: zabbix
  tasks:
  - name: push backup result to weiChat
    remote_user: root
    shell: bash /root/Ansible_Playbook/Script/bakResult.sh

  - name: drop expired data
    remote_user: root
    script: /usr/bin/ls /root/bakOCH |grep bakF |xargs -I @ /usr/bin/find /root/bakOCH/@ -type d -mtime +1 -maxdepth 1|xargs rm -rf

```

恢复脚本(syncUAT.sh)
```shell
#!/bin/bash 
#Auth:Qing.Yu
#Mail:1753330141@qq.com
# Ver:V1.4
#Date:2018-09-26
 
#获取当前日期
source ~/.bash_profile
d=`/bin/date +%Y-%m-%d` 
p='/root/bakHTOA8000V8'
cd $p/$d

#定义数据备份文件名
dmp_file=`/bin/ls -lt *.dmp|awk 'NR==1{print $9}'`

#复制备份数据库文件至oracle数据库服务器
scp $dmp_file oracle@10.xxx.xxx.xx:/media/ORADATA/DBSoftware/app/oracle/admin/OAPROD8/dpdump

#关闭本地tomcat进程
ps -ef|grep tomcat |awk '{print $2}' |awk '{print}'|xargs kill

#ssh至oracle服务器
ssh oracle@xx.xxx.xxx.xx<<EOF
#清理归档日志
echo "delete noprompt archivelog until time 'sysdate-3' ;"|rman target sys/xxxxxxxx@OAPROD8
#清空UAT数据库
echo 'drop user htoa8000 cascade;'|sqlplus sys/xxxxxxxx@OAPROD8 as sysdba
#导入备份数据
impdp \"sys/xxxxxxxx@OAPROD8 as sysdba\" directory=DATA_PUMP_DIR dumpfile=$dmp_file schemas=htoa8000 encryption_password=xxxxxxxx;
#重置HTOA8000账号密码
echo 'alter user HTOA8000 identified by \"xxxxxxxx\"' |sqlplus sys/xxxxxxxx@OAPROD8 as sysdba
#解锁HTOA8000账号
echo 'alter user HTOA8000 account unlock' |sqlplus sys/xxxxxxxx@OAPROD8 as sysdba
#重置用户密码
echo "update user_user set password='e10adc3949xxxxxxxx883e';" | sqlplus htoa8000/xxxxxxxx@OAPROD8
EOF

#清空模板目录
rm -rf /home/htoa/tomcat/webapps/ROOT/htoa/template/

# 解压缩模板文件
unzip -P xxxxxxxx $d"_template.zip"

#转移至UAT环境
mv home/htoa/tomcat/webapps/ROOT/htoa/template/ /home/htoa/tomcat/webapps/ROOT/htoa/

#启动OA服务
cd /home/htoa/tomcat/bin/
./startup.sh

```
