### 需求背景
致远、华天动力等厂商的OA产品，支持Linux & Oracle环境，通过脚本方式，解决手工方式进行生产环境备份、测试环境同步时，操作繁琐而且容易存在疏漏的缺陷。
##### 建议部署堡垒机，隔离运维人员在无审计手段的情况下，直接操作服务
### 参考资料
- Linux Shell脚本攻略（第2版）；
- Oracle 11g权威指南(第2版) ；
 
### 方案设计
 
以Linux环境下的应用（tomcat）和数据库（oracle）的测试环境同步为例，同步内容包含两部分：应用系统的文件和数据库系统，生产和测试环境涉及几个动作：
1. 导出文件从生产环境导出到逻辑甚至物理隔离的测试环境；
2. 测试环境完成数据库清空、应用系统文件删除；
3. 导出文件在测试环境数据库的导入、应用系统文件的恢复；

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
