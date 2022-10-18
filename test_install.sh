#!/bin/bash
#set -x
#set -u
set -e

server_port=$(shuf -i20001-65535 -n1)
password="jGHui1PTuCLA4hNRh168-t"
encrypt_method="xchacha20-ietf-poly1305"
domain=
only_config=false


usage()
{
cat <<EOF >&2

$0 options${txtrst}

${txtbld}OPTIONS${txtrst}:

  -p <server_port>      Port number of your remote server.
                        The default server_port is $(tput setaf 3)$server_port$(tput sgr0)

  -k <password>         Password of your remote server.
                        The default password is $(tput setaf 3)$password$(tput sgr0)

  -m <encrypt_method>   Encrypt method:
                        chacha20-ietf-poly1305,xchacha20-ietf-poly1305,
                        salsa20, chacha20 and chacha20-ietf.
                        The default cipher is $(tput setaf 3)$encrypt_method.$(tput sgr0)
  -d <domain>           Your domain. $(tput setaf 1)[NECESSARY]$(tput sgr0)

  -c                    Only editing the config file. $(tput setaf 1)[OPTIONAL]$(tput sgr0)

EOF
}


while getopts "hp:k:m:d:c" OPTION
do
        case $OPTION in
                h)
                        usage
                        exit 1
                        ;;
                p)
                        server_port=$OPTARG
                        ;;
                k)
                        password=$OPTARG
                        ;;
                m)
                        encrypt_method=$OPTARG
                        ;;
                d)
                        domain=$OPTARG
                        ;;
                c)
                        only_config=true
                        ;;
                ?)
                        usage
                        exit 1
                        ;;
        esac
done


if [ -z $domain ]; then
        usage
        exit 1
fi


if [ "$only_config" != true ]; then
        echo "----#install ss-server----"

        #enable ufw
        sudo ufw allow 80
        sudo ufw allow 443
        sudo ufw allow $server_port
        sudo ufw status
        
        #install apache2
        apt update
        apt-get install apache2 -y
        
        #get CA
        curl  https://get.acme.sh | sh
        ./.acme.sh/acme.sh --set-default-ca  --server  letsencrypt
        ./.acme.sh/acme.sh --issue  -d $domain --apache --force

        #install shadowsocks-libev
        apt install shadowsocks-libev -y
        ps -ef | grep "/usr/bin/ss-server" |grep -v "grep"| awk '{print $2}' | xargs sudo kill -9

        #install v2ray-plugin
        snap install go --classic
        wget https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.1/v2ray-plugin-linux-amd64-v1.3.1.tar.gz
        tar -zxvf v2ray-plugin-linux-amd64-*.tar.gz
        mv v2ray-plugin_linux_amd64 /usr/bin/v2ray-plugin

fi

#----------------------
echo "----#edit config----"
#config.json
cat <<END >/etc/shadowsocks-libev/config.json
{
    "server":["[::0]","0.0.0.0"], 
    "nameserver": "8.8.8.8",
    "server_port":$server_port,
    "local_port":1080,
    "password":"$password",
    "method":"$encrypt_method",
    "timeout": 600,
    "no_delay": true,
    "mode": "tcp_only",
    "plugin": "/usr/bin/v2ray-plugin",
    "plugin_opts": "server;tls;host=$domain;path=/ue1cdh3vrpuj;loglevel=none;cert=/root/.acme.sh/$domain/fullchain.cer;key=/root/.acme.sh/$domain/$domain.key"
}
END

#ss.servic
cat <<END >/etc/systemd/system/ss.service
[Unit]
Description=Shadowsocks Server
After=network.target
[Service]
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json 
Restart=on-abort
[Install]
WantedBy=multi-user.target
END

#----------------------
echo "----#ss start----"
#systemctl enable ss
systemctl daemon-reload
systemctl restart ss
systemctl status ss -l

echo ""
echo "#------------"
echo "IP address is `ifconfig | sed -n '2p' | cut -d ' ' -f 10`" | tee ss_install.log
echo "server port is $server_port" | tee -a ss_install.log
echo "password is $password" | tee -a ss_install.log
echo "method is $encrypt_method" | tee -a ss_install.log
echo "domain is $domain" | tee -a ss_install.log
echo "plugin is 'v2ray-plugin_windows_amd64'"
echo "plugin-opts is 'tls;host=$domain;path=/ue1cdh3vrpuj;'" | tee -a ss_install.log

