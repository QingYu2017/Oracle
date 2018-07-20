#定义数据备份文件名
dmp_file=bak_2018-07-20_15237581_OA8000V8.dmp

#复制备份数据库文件至oracle数据库服务器
scp $dmp_file oracle@10.xxx.xxx.xx:/media/ORADATA/DBSoftware/app/oracle/admin/OAPROD8/dpdump

#关闭本地tomcat进程
ps -ef|grep tomcat |awk '{print $2}' |awk 'NR==1{print}'|xargs kill

#ssh至oracle服务器
ssh oracle@10.xxx.xxx.xx<<EOF

#清空UAT数据库
echo 'drop user htoa8000 cascade;'|sqlplus sys/xxxxxxxx@OAPROD8 as sysdba

#导入备份数据
impdp \"sys/xxxxxxxx@OAPROD8 as sysdba\" directory=DATA_PUMP_DIR dumpfile=$dmp_file schemas=htoa8000 encryption_password=xxxxxxxx;

#重置用户密码
echo "update user_user set password='e10adc3949ba59abbe56e057f20f883e';" | sqlplus htoa8000/xxxxxxxx@OAPROD8
EOF
#清空模板目录
rm -rf /home/htoa/tomcat/webapps/ROOT/htoa/template/

# 解压缩模板文件
unzip template2018-07-20.zip

#转移至UAT环境
mv home/htoa/tomcat/webapps/ROOT/htoa/template/ /home/htoa/tomcat/webapps/ROOT/htoa/

#启动OA服务
bash /home/htoa/tomcat/bin/startup.sh
