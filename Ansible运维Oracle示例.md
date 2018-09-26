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


![执行示例](https://github.com/QingYu2017/pic/blob/master/jserver_log.gif)

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
