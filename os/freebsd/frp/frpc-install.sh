#!/bin/sh

if [ $# -ne 3 ]
then
    echo "usage: frpc-install [arch=x86,arm64] [host] [remote-port]"
    exit 1
fi

arch=$1
host=$2
port=$3

# download
if [ $host == "x86" ]
then
    wget https://github.com/fatedier/frp/releases/download/v0.45.0/frp_0.45.0_freebsd_amd64.tar.gz -O /home/freebsd/frp.tar.gz
elif [ $host == "arm64" ]
then
    cp ./frp-arm64.tar.gz /home/freebsd/frp.tar.gz
else
    echo "no support now"
    exit 1
fi

cd /home/freebsd
mkdir frp && tar -zxf frp.tar.gz -C frp --strip-components 1

# configure
cd /home/freebsd/frp
cat > frpc.ini <<EOF
[common]
server_addr = 47.100.73.173
server_port = 8000

[$host-ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = $port
EOF

# rc for frpc
cd /usr/local/etc/rc.d
cat > frpc <<EOF
#!/bin/sh
# PROVIDE: frpc
# REQUIRE: login
# KEYWORD: nojail start

. /etc/rc.subr

name="frpc"
desc="frp client"
rcvar="frpc_enable"
command="/home/freebsd/frp/frpc"
command_args="-c /home/freebsd/frp/frpc.ini &"

load_rc_config \$name
run_rc_command "\$1"
EOF
echo "frpc_enable=\"YES\"" >> /etc/rc.conf
chmod +x frpc

# start
service frpc enable
service frpc start
