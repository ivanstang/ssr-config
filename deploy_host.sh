#!/bin/bash

#### Description: 自动部署docker服务器
#### System requirement: Ubuntu 18.04
#### Written by: York Tang - ivanstang0415@gmail.com on 02-2019

# 自定义输出文本颜色
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

# 检查bbr设置
check_bbr(){
	check_bbr_status_on=`sysctl net.ipv4.tcp_congestion_control | awk '{print $3}'`
	if [[ "${check_bbr_status_on}" = "bbr" ]]; then
		check_bbr_status_off=`lsmod | grep bbr`
		if [[ "${check_bbr_status_off}" = "" ]]; then
			return 1
		else
			return 0			
		fi
	else
		return 2
	fi
}

# 应用bbr
enable_bbr(){
	check_bbr
	if [[ $? -eq 0 ]]; then
		echo -e "${Info} BBR 已在运行 !"
	else
		sed -i '/net\.core\.default_qdisc=fq/d' /etc/sysctl.conf
    	sed -i '/net\.ipv4\.tcp_congestion_control=bbr/d' /etc/sysctl.conf

    	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    	echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    	sysctl -p >> /var/log/bbr.log

		sleep 1s
		
		check_running
		case "$?" in
		0)
		echo -e "${Info} BBR 已成功启用 !"
		;;
		1)
		echo -e "${Error} Linux 内核已经启用 BBR，但 BBR 并未运行 ！"
		;;
		2)
		echo -e "${Error} Linux 内核尚未配置启用 BBR ！"
		;;
		*)
		echo "${Error} BBR 状态未知，返回参数: $?}"
		;;
		esac
	fi
}

# 读取ddns配置
read_ddns_config(){
    DDNS_CONF=/root/ssr-config/ddns-config.json
    if [ ! -f ${DDNS_CONF} ]; then
        cat > ${DDNS_CONF}<<-EOF
{
"host": "xxxx",
"key": "yyyy"
}
EOF
    fi
    HOST=`cat ${DDNS_CONF} | jq '.host' | sed 's/\"//g'`
    KEY=`cat ${DDNS_CONF} | jq '.key' | sed 's/\"//g'`
}

# 修改DDNS主机名
change_ddns_host(){
    read_ddns_config
    echo -e "请输入主机名"
    read -e -p "(当前: ${HOST}):" NEW_HOST
    if [ ! -z "${NEW_HOST}" ]; then
        sed -i "s/${HOST}/${NEW_HOST}/g" "$DDNS_CONF"
        read_ddns_config
        [[ "$HOST" != "$NEW_HOST" ]] && echo -e "${Error} 主机名修改失败 !" && exit 1
        echo -e "${Info} 主机名已修改为 ${NEW_HOST} !"
    fi
    echo -e "请输入DDNS更新的KEY"
    read -e -p "(当前: ${KEY}):" NEW_KEY
    if [ ! -z "${NEW_KEY}" ]; then
        sed -i "s/${KEY}/${NEW_KEY}/g" "$DDNS_CONF"
        read_ddns_config
        [[ "$KEY" != "$NEW_KEY" ]] && echo -e "${Error} DDNS更新KEY修改失败 !" && exit 1
        echo -e "${Info} DDNS更新KEY已修改为 ${NEW_KEY} !"
    fi
}
 
# 检验DDNS修改是否有效
verify_ddns(){
    read_ddns_config
    RESULT=`curl -4 "${HOST}:${KEY}@dyn.dns.he.net/nic/update?hostname=${HOST}"`
    if [[ $RESULT =~ "good" ]]; then
        echo -e "${Info} DDNS配置测试成功 !"
    elif [[ $RESULT =~ "nochg" ]]; then
        echo -e "${Info} DDNS配置测试成功 !"
    else
        echo -e "${Error} DDNS配置测试失败：$RESULT !"
    fi
}

# 读取json配置文件中的密码
read_json_password(){
    if [ ! -f ${CONF_FILE}]; then
        echo "找不到配置文件 ${CONF_FILE}, 退出！"
        exit 1
    fi
    PASSWORD=`cat ${CONF_FILE} | jq '.password' | sed 's/\"//g'`
}

# 读取conf配置文件中的密码
read_conf_password(){
    if [ ! -f ${CONF_FILE}]; then
        echo "找不到配置文件 ${CONF_FILE}, 退出！"
        exit 1
    fi
    PASSWORD=`cat ${CONF_FILE} | grep '-k' | awk '{print $2}'
}

# 配置SSR连接密码
config_password(){
    CONF_FILE="/root/ssr-config/shadowsocksr-config"
    read_json_password
    echo -e "请输入SSR的连接密码"
    read -e -p "(当前的密码是: ${PASSWORD}):" NEW_PASSWORD
    if [ ! -z "${NEW_PASSWORD}" ]; then
        sed -i "s/${PASSWORD}/${NEW_PASSWORD}/g" "${CONF_FILE}"
        read_json_password
        [[ "${PASSWORD}" != "${NEW_PASSWORD}" ]] && echo -e "${Error} SSR连接密码修改失败 !" && exit 1
        echo -e "${Info} SSR连接密码已修改为 ${NEW_PASSWORD} !"
    fi

    CONF_FILE="/root/ssr-config/udpspeeder-config.json"
    read_json_password
    echo -e "请输入UDPSpeeder的连接密码"
    read -e -p "(当前的密码是: ${PASSWORD}):" NEW_PASSWORD
    if [ ! -z "${NEW_PASSWORD}" ]; then
        sed -i "s/${PASSWORD}/${NEW_PASSWORD}/g" "${CONF_FILE}"
        read_json_password
        [[ "${PASSWORD}" != "${NEW_PASSWORD}" ]] && echo -e "${Error} UDPSpeeder连接密码修改失败 !" && exit 1
        echo -e "${Info} UDPSpeeder连接密码已修改为 ${NEW_PASSWORD} !"
    fi

    CONF_FILE="/root/ssr-config/udp2raw.conf"
    read_conf_password
    echo -e "请输入UDPSpeeder的连接密码"
    read -e -p "(当前的密码是: ${PASSWORD}):" NEW_PASSWORD
    if [ ! -z "${NEW_PASSWORD}" ]; then
        sed -i "s/${PASSWORD}/${NEW_PASSWORD}/g" "${CONF_FILE}"
        read_conf_password
        [[ "${PASSWORD}" != "${NEW_PASSWORD}" ]] && echo -e "${Error} UDPSpeeder连接密码修改失败 !" && exit 1
        echo -e "${Info} UDPSpeeder连接密码已修改为 ${NEW_PASSWORD} !"
    fi
}

apt update && apt install -y docker.io jq
enable_bbr
mkdir /root/ssr-config
wget -N --directory-prefix=/root/ssr-config https://raw.githubusercontent.com/ivanstang/ssr-config/master/ddns-config.json
wget -N --directory-prefix=/root/ssr-config https://raw.githubusercontent.com/ivanstang/ssr-config/master/shadowsocksr-config.json
wget -N --directory-prefix=/root/ssr-config https://raw.githubusercontent.com/ivanstang/ssr-config/master/udp2raw.conf
wget -N --directory-prefix=/root/ssr-config https://raw.githubusercontent.com/ivanstang/ssr-config/master/udpspeeder-config.json
change_ddns_host
verify_ddns
config_password
docker rm -f ssr
docker rm -f ubuntu
docker rmi -f ivanstang/ssr:with-udp-speedup
docker run -itd -v /root/ssr-config:/ssr-config --name ssr --net host ivanstang/ssr:with-udp-speedup
docker exec -d ssr /bin/bash -c "/etc/init.d/docker_post.sh"
