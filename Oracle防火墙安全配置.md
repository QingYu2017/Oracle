```shell
Auth: Qing.Yu
Mail: 1753330141@qq.com
 Ver: V1.0
Date: 2019-02-01
``` 
### 摘要说明
数据库安全是业务平稳运行的核心，尽管可以使用硬件防火墙、交换/路由设备的ACL策略进行安全加固，通过服务器本地防火墙进行防护，仍然是距离核心数据库最近、也最有效的一道保障。本案例以公司使用的Oracle数据库本地防火墙策略为例，演示iptables的配置，实现特定地址/网络之间的相互访问控制。

### 设计目的：
- 允许本地的oem开放对外访问（端口5500，见$ORACLE_HOME/install/portlist.ini）；
- 允许本地访问外部地址，如10.xxx.xxx.41的1433端口；
- 允许特定地址访问本地的管理端口22（10.xxx.xx.55、10.xxx.xx.21和10.xxx.xx.21），允许特定地址访问本地的应用端口1521（10.xxx.xxx.41和10.xxx.xx.33）；
- 放通ORADB01主机访问XX兑换业务服务器数据库（29.x.xx.2:1521）进行数据泵备份，放通Ansible服务器（10.xxx.xx.55）的日常文件备份操作；

### 参考资料：
- 谷长勇. Oracle 11g权威指南.第2版[M]. 电子工业出版社, 2011.
- 佚名. TCP/IP协议及网络编程技术[M]. 2004.
- 佚名. 红旗Linux网络管理教程[M]. 2001.

### 发现问题：
- 如果不开放本机访问（127.0.0.1），oem在启停时将尝试与安装信息中指定的hosts通信，并启动对应实例（$ORACLE_SID）的oem，当iptables阻断本机通信，会造成oem启停失败，dbstart/dbshutdown也应存在相同问题。

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
