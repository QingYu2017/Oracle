* Auth:Qing.Yu
* Mail:1753330141@qq.com
*  Ver:V1.0
* Date:2018-09-28

### 需求说明
部分业务场景下，需要在指定日期对oracle账号进行启停维护，如对与特定业务、特定用户，开放指定时间内的oracle访问权限。
oracle自身带有设置账号密码有效期等功能，但是用户如果主动修改密码，则有效期顺延，起不到管理的作用。

### 处理方案
部署在Linux环境下的Oracle，借助定时任务（Crontab）、Zabbix、Ansible等工具，定时执行操作脚本，检测到账号启停日期与当前日期一致即可进行相应操作，可以很方便的达到以上目的。

### 参考资料
- Linux Shell脚本攻略（第2版）；
- Oracle 11g权威指南(第2版) ；

### 方案设计
1. 创建脚本
  1. 通过ssh登录oracle主机；
  2. 执行oracle操作完成数据库用户的启停；
2. 在控制主机配置到oracle服务器的密钥认证方式登录；
3. 在控制主机上配置定时任务

### 验证脚本和注意事项
1. 创建用户
```
echo 'create user test1 identified by password;'|sqlplus sys/password@OAPROD8 as sysdba
```
2. 变更用户启停
```
echo 'alter user test1 account lock;' |sqlplus sys/password@OAPROD8 as sysdba
echo 'alter user test1 account unlock;' |sqlplus sys/password@OAPROD8 as sysdba
```
3. 检查用户状态
```
echo "select username,account_status from dba_users where username='TEST1';" |sqlplus sys/password@OAPROD8 as sysdba
```
4. 注意
当用户处理链接状态，特别是如O32的trade用户或OA的数据库用户，会发起多个连接进程，此时无法直接对账户进行禁用，可先终止应用服务到数据库的连接，再lock用户。
如果管理员授权范围仅限oracle，可以先变更用户密码，再在oracle内部kill session，最后lock用户。
5. 延伸思考
- 如需要对多个数据库服务器/实例上的用户，按照指定日期进行启停操作，在如下脚本中添加相应流程判断即可；
- 执行结果可以通过推送微信信息，提醒相应的管理人员知晓；
- 如果使用flask等框架，可以构造基于python的运维管理工具，整合到公司的运维管理平台，便于复核和审计，同时维护目标账户信息/所在服务器/实例名等信息，保存至数据库管理；


```shell
#!/bin/bash 
#Auth:Qing.Yu
#Mail:1753330141@qq.com
# Ver:V1.0
#Date:2018-09-28

ssh oracle@10.666.100.66<< EOF
'
d=`/bin/date +%Y%m%d` 
if [ $d=='2018-09-28' ]; then
    echo 'alter user test1 account lock' |sqlplus sys/password@OAPROD8 as sysdba
fi 
'
EOF
```
执行结果对比
![执行结果对比](https://github.com/QingYu2017/pic/blob/master/10.png)

微信提醒
![微信提醒](https://github.com/QingYu2017/pic/blob/master/11.png)
