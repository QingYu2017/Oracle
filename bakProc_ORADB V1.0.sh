#!/bin/bash 
#Auth:Qing.Yu
#Mail:1753330141@qq.com
# Ver:V1.0
#Date:2018-05-20

#远程Oracle主机，切换oracle账号备份数据
#注意，如果是在Oracle本机运行，则EOF之间的代码，要去掉$d前的\转义符
ssh root@10.xxx.xxx.31<< EOF
su - oracle -c '
d=`/bin/date +%Y%m%d` 
expdp \"sys/1234xxxx@OAPROD as sysdba\" directory=DATA_PUMP_DIR dumpfile=bak_"\$d"_OA8000V7.dmp schemas=OA8000  compression=all;
expdp \"sys/1234xxxx@OAPROD8 as sysdba\" directory=DATA_PUMP_DIR dumpfile=bak_"\$d"_OA8000V8.dmp schemas=OA8000  compression=all;
'
EOF

#拷贝数据库至文件服务器，并将更新结果写入日志
d=`/bin/date +%Y%m%d`
scp root@10.xxx.xxx.31:"/media/ORADB/DBSoftware/app/oracle/admin/OAPROD/dpdump/bak_"$d"_OA8000V7.dmp" "/root/bakORADB/bakFolder/bak_"$d"_OA8000V7.dmp"
scp root@10.xxx.xxx.31:"/media/ORADB/DBSoftware/app/oracle/admin/OAPROD8/dpdump/bak_"$d"_OA8000V8.dmp" "/root/bakORADB/bakFolder/bak_"$d"_OA8000V8.dmp"
ls -l /root/bakORADB/bakFolder/ |grep $d.*dmp >>/root/bakORADB/bakFolder/bakORADBLog.log

