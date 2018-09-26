### 需求背景
协同办公（OA）等系统在新功能上线前，都需要使用测试环境进行业务验证，测试时应尽可能使用真实的生产数据进行业务测试，如表单样式、组织架构设置、人员基本信息应尽可能和生产保持一致。因此，在不考虑数据脱敏的情况下，都需要能够准确、快速的完成数据同步。对于投资交易系统，涉及到持仓数据、风控设置、投资/风控/交易等人员权限，也应同样具备快速同步的能力。
### 参考资料
- Ansible is Simple IT Automation（ https://www.ansible.com/ ）；
- Linux Shell脚本攻略（第2版）；
- Ansible自动化运维：技术与最佳实践 (实战)；       
 
### 方案设计
 
以Linux环境下的应用（tomcat）和数据库（oracle）为例，同步内容包含两部分：应用系统的文件和数据库系统，生产和测试环境涉及几个动作：
1. 生产数据库的导出（rman或数据泵方式）；
2. 应用系统的文件（如OA附件）的导出；
3. 导出文件从生产环境导出到逻辑甚至物理隔离的测试环境；
4. 测试环境完成数据库清空、应用系统文件删除；
5. 导出文件在测试环境数据库的导入、应用系统文件的恢复；

### 示例

备份剧本（通过Ansible执行）

```yml
#Auth:Qing.Yu
#Mail:1753330141@qq.com
# Ver:V1.0
#Date:2018-08-09
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
      paths: /root/bakHTOA8000V8/
      patterns: "*.zip"
    register: file_2_fetch
 
  #移动文件至zbx挂载的nfs路径中的日期目录中
  - name: move backup files to file server
    remote_user: root
    fetch:
      src: "{{ item.path}}"
      dest: /root/bakOCH/bakFolder/{{ ansible_date_time.date }}/
      flat: yes
    with_items: "{{ file_2_fetch.files }}"
 
  #删除应用服务器上产生的临时压缩文件
  - name: remove backup files
    remote_user: root
    file:
      path: "{{ item.path}}"   
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
      src: "{{ item.path}}"
      dest: /root/bakOCH/bakFolder/{{ ansible_date_time.date }}/
      flat: yes
    with_items: "{{ file_2_fetch.files }}"
  
  #删除数据库产生的dump文件
  - name: remove dump files
    remote_user: oracle
    file:
      path: "{{ item.path}}"   
      state: absent
    with_items: "{{ file_2_fetch.files }}"
 
#推送微信通知信息
- hosts: zabbix
  tasks:
  - name: push backup result to weiChat
    remote_user: root
    shell: bash /root/Ansible_Playbook/Script/bakResult.sh
 

恢复脚本（通过Shell执行）
#获取当前日期
d=`/bin/date +%Y-%m-%d`
 
#定义数据备份文件名
dmp_file=`/bin/ls -l *.dmp|awk 'NR==1{print $9}'`
 
#复制备份数据库文件至oracle数据库服务器
scp $dmp_fileoracle@10.xxx.xxx.31:/media/ORADATA/DBSoftware/app/oracle/admin/OAPROD8/dpdump
 
#关闭本地tomcat进程
ps -ef|grep tomcat |awk '{print $2}' |awk '{print}'|xargs kill
 
#ssh至oracle服务器
sshoracle@10.xxx.xxx.31<<EOF
#清理归档日志
echo "delete noprompt archiveloguntil time 'sysdate-3' ;"|rmantarget sys/xxxxxxxx@OAPROD8
#清空UAT数据库
echo 'drop user htoa8000 cascade;'|sqlplus sys/xxxxxxxx@OAPROD8 as sysdba
#导入备份数据
impdp\"sys/xxxxxxxx@OAPROD8 as sysdba\" directory=DATA_PUMP_DIR dumpfile=$dmp_fileschemas=htoa8000 encryption_password=xxxxxxxx;
#重置HTOA8000账号密码
#echo 'alter user HTOA8000 identified by \"xxxxxxxx\"' |sqlplussys/xxxxxxxx@OAPROD8 as sysdba
echo 'alter user HTOA8000 identified by xxxxxxxx' |sqlplussys/xxxxxxxx@OAPROD8 as sysdba
#解锁HTOA8000账号
echo 'alter user HTOA8000 account unlock' |sqlplussys/xxxxxxxx@OAPROD8 as sysdba
#重置用户密码
echo "update user_user set password='e10adcxxxxxxxxf883e';" | sqlplus htoa8000/xxxxxxxx@OAPROD8
EOF
 
#清空模板目录
rm -rf /home/htoa/tomcat/webapps/ROOT/htoa/template/
 
# 解压缩模板文件
unzip $d"_template.zip"
 
#转移至UAT环境
mv home/htoa/tomcat/webapps/ROOT/htoa/template/ /home/htoa/tomcat/webapps/ROOT/htoa/
 
#启动OA服务
cd /home/htoa/tomcat/bin/
./startup.sh
```

![执行示例](https://github.com/QingYu2017/pic/blob/master/jserver_log.gif)

恢复脚本
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
#echo 'alter user HTOA8000 identified by \"xxxxxxxx\"' |sqlplus sys/xxxxxxxx@OAPROD8 as sysdba
echo 'alter user HTOA8000 identified by htoa8000' |sqlplus sys/xxxxxxxx@OAPROD8 as sysdba
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
