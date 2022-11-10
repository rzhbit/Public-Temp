#!/bin/bash
#set -x
#set -u
set -e

server_port=$(shuf -i20001-65535 -n1)
password="]5.t!YQj-vCAv}5#gZ!C"
encrypt_method="xchacha20-ietf-poly1305"
domain=

install_ss=false
install_apach=false

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
                        chacha20-ietf-poly1305,xchacha20-ietf-poly1305,salsa20, chacha20 and chacha20-ietf.
                        The default cipher is $(tput setaf 3)$encrypt_method.$(tput sgr0)
                        
  -d <domain>           Your domain. $(tput setaf 1)[NECESSARY]$(tput sgr0)

  -c                    Install ss-v2ray server. $(tput setaf 1)[OPTIONAL] The default is false $(tput sgr0)
  
  -n                    Install apach2 server. $(tput setaf 1)[OPTIONAL] The default is false $(tput sgr0)

EOF
}


while getopts "hp:k:m:d:cn" OPTION
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
                        install_ss=true
                        ;;
                n)
                        install_apach=true
                        ;;
                ?)
                        usage
                        exit 1
                        ;;
        esac
done

#------
domain_check() {
        #
        if [ -z $domain ]; then
                usage
                exit 1
        fi
        #getip
        ip=$(curl -s https://ipinfo.io/ip)
        [[ -z $ip ]] && ip=$(curl -s https://api.ip.sb/ip)
        [[ -z $ip ]] && ip=$(curl -s https://api.ipify.org)
        [[ -z $ip ]] && ip=$(curl -s https://ip.seeip.org)
        [[ -z $ip ]] && ip=$(curl -s https://ifconfig.co/ip)
        [[ -z $ip ]] && ip=$(curl -s https://api.myip.com | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
        [[ -z $ip ]] && ip=$(curl -s icanhazip.com)
        [[ -z $ip ]] && ip=$(curl -s myip.ipip.net | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
        [[ -z $ip ]] && echo -e "\n$red 无法获得ip地址！$none\n" && exit
        #cheakdomain
        # test_domain=$(dig $domain +short)
        test_domain=$(ping $domain -c 1 -W 4 | grep -oE -m1 "([0-9]{1,3}\.){3}[0-9]{1,3}")
        # test_domain=$(wget -qO- --header='accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$domain&type=A" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -1)
        # test_domain=$(curl -sH 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$domain&type=A" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -1)
        if [[ $test_domain != $ip ]]; then
                echo
                echo -e "$red 检测域名解析错误....$none"
                echo
                echo -e " 你的域名: $yellow$domain$none 未解析到: $cyan$ip$none"
                echo
                echo -e " 你的域名当前解析到: $cyan$test_domain$none"
                echo
                echo "备注...如果你的域名是使用 Cloudflare 解析的话..在 Status 那里点一下那图标..让它变灰"
                echo
                #exit 1
        fi
}

domain_check

#------ufw config-------
#delete ufw
for n in $(sudo ufw status|grep "v6"|cut -d ' ' -f 1 |awk '{if($1!="22"&&$1!="80"&&$1!="443") print $1}')
do
    sudo ufw delete allow $n
done

#allow ufw
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow $server_port
sudo ufw status

#--------ca--------
echo /root/.local/share/caddy/certificates/*/$domain > caddy_tmp_32cd6e1c98ee.txt
crtpath=$(cat caddy_tmp_32cd6e1c98ee.txt)
rm -f caddy_tmp_32cd6e1c98ee.txt
ca_crt=${crtpath}/${domain}.crt
ca_key=${crtpath}/${domain}.key

#------install apache------
if [ "$install_apach" != false ]; then 
        echo "----#install apache2----"
        #install apache2
        apt update
        apt-get install apache2 -y
        #get CA
        curl  https://get.acme.sh | sh
        ./.acme.sh/acme.sh --set-default-ca  --server  letsencrypt
        ./.acme.sh/acme.sh --issue  -d $domain --apache --force
        ca_crt=/root/.acme.sh/${domain}/fullchain.cer
        ca_key=/root/.acme.sh/${domain}/centieping.tk.key
fi

#------install ss-v2ray------
if [ "$install_ss" != false ]; then
        echo "----#install ss-server----"
        #install shadowsocks-libev
        apt update
        apt install shadowsocks-libev -y
        #install v2ray-plugin
        snap install go --classic
        wget https://github.com/shadowsocks/v2ray-plugin/releases/download/v1.3.1/v2ray-plugin-linux-amd64-v1.3.1.tar.gz
        tar -zxvf v2ray-plugin-linux-amd64-*.tar.gz
        mv v2ray-plugin_linux_amd64 /usr/bin/v2ray-plugin
        ps -ef | grep "/usr/bin/ss-server" |grep -v "grep"| awk '{print $2}' | xargs sudo kill -9
fi
#----------------------


echo "----#edit config----"
#config.json
cat <<END >/etc/shadowsocks-libev/config.json
{
    "server": "0.0.0.0", 
    "nameserver": "8.8.8.8",
    "server_port":$server_port,
    "local_port":1080,
    "password":"$password",
    "method":"$encrypt_method",
    "timeout": 600,
    "no_delay": true,
    "mode": "tcp_only",
    "plugin": "/usr/bin/v2ray-plugin",
    "plugin_opts": "server;tls;host=$domain;path=/ue1cdh3vrpuj;loglevel=none;cert=${ca_crt};key=${ca_key}"
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
echo "IP address is $ip" | tee ss_install.log
echo "server port is $server_port" | tee -a ss_install.log
echo "password is $password" | tee -a ss_install.log
echo "method is $encrypt_method" | tee -a ss_install.log
echo "domain is $domain" | tee -a ss_install.log
echo "plugin is 'v2ray-plugin_windows_amd64'" 
echo "plugin-opts is 'tls;host=$domain;path=/ue1cdh3vrpuj;'" | tee -a ss_install.log

