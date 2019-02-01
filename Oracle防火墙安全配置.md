* Auth: Qing.Yu
* Mail: 1753330141@qq.com
*  Ver: V1.0
* Date: 2019-02-01

### 设计目的：
- 允许本地的oem开放对外访问（端口5500，见$ORACLE_HOME/install/portlist.ini）；
- 允许本地访问外部地址，如10.xxx.xxx.41的1433端口；
- 允许特定地址访问本地的管理端口22（10.xxx.xx.55、10.xxx.xx.21和10.xxx.xx.21），允许特定地址访问本地的应用端口1521（10.xxx.xxx.41和10.xxx.xx.33）；
- 防火墙不应影响ORADB01主机访问XX兑换业务服务器数据库（29.x.xx.2:1521），放通过Ansible服务器（10.xxx.xx.55）的日常文件备份操作；

### 参考资料：
- 谷长勇. Oracle 11g权威指南.第2版[M]. 电子工业出版社, 2011.
- 佚名. TCP/IP协议及网络编程技术[M]. 2004.
- 佚名. 红旗Linux网络管理教程[M]. 2001.

### 发现问题：
- 如果限制了本地访问（127.0.0.1），oem在启停时，尝试与hosts指定的oracle实例（$ORACLE_SID）通信失败，会造成oem启停失败，dbstart/dbshutdown也应存在相同问题。

![示例](https://github.com/QingYu2017/pic/blob/master/21.png)

### 配置示例：
![示例](https://github.com/QingYu2017/pic/blob/master/20.png)
```shell
#本机访问策略
iptables -A INPUT -s 127.0.0.1 -d 127.0.0.1 -j ACCEPT
#标准管理接口策略
iptables -A INPUT -s 10.xxx.xx.55 -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -s 10.xxx.xx.21 -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -s 10.xxx.xx.21 -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -s 10.xxx.xx.55 -p tcp --dport 10050 -j ACCEPT
#对外服务策略
iptables -A INPUT -p tcp --dport 5500 -j ACCEPT
iptables -A INPUT -s 10.xxx.xx.33 -p tcp --dport 1521 -j ACCEPT
iptables -A INPUT -s 10.xxx.xxx.41 -p tcp --dport 1521 -j ACCEPT
#对外访问策略
iptables -A OUTPUT -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
#缺省禁止策略
iptables -A INPUT -j REJECT 
```
