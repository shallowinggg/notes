# 安装方式
* [all](https://www.postgresql.org/download/)
* [ubuntu](https://www.postgresql.org/download/linux/ubuntu/)
# 连接

PostgreSQL安装后默认会创建一个系统用户 `postgres` ，切换至此用户并输入 `psql` 即可通过本地客户端连接。

## 增加用户

注意：以下命令需要在 `psql` 中输入

创建空白用户：

```sql
CREATE ROLE test;
```

创建用户并赋予权限以及密码（推荐配置）：

```sql
CREATE ROLE test LOGIN CREATEDB CREATEROLE PASSWORD 'xxx';

```

其中 `LOGIN`  `CREATEDB`  `CREATEROLE` 都为权限选项。具体参见[Role Attributes](https://www.postgresql.org/docs/14/role-attributes.html)。

输入 `\du` 即可查看创建的用户。

## 本地连接

输入 `psql postgres -h 127.0.0.1` 并输入密码即可连接。本地连接新用户默认通过 `peer` 方式连接，因此需要通过 `-h 127.0.0.1` 额外指定当前ip（此处 `postgres` 为数据库名称）。

如果不指定 `postgres` ，默认会连接到与用户名相同的数据库，如果此数据库不存在那么需要预先创建，然后通过 `psql -h 127.0.0.1` 即可连接。

### 通过密码连接

修改 `pg_hba.conf` 文件

```
local   all             postgres                                peer

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local	  all		          test					                          md5
local   all             all                                     peer
```

在默认配置项 `local   all             all                                     peer` 之上增加 `local	  all		          test		                        md5` ，然后刷新此文件。

刷新方式：
* 在 `psql` 中执行 `SELECT pg_reload_conf(); `
* 重启postgres服务器
* 执行命令`pg_ctl reload`。

即可通过密码（ `psql postgres` ）连接到服务器。
