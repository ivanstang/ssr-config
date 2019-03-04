#!/bin/bash

FILE="/root/deploy_host.sh"
if [ -f ${FILE} ]; then
	rm ${FILE}
fi

wget -N --directory-prefix=/root https://raw.githubusercontent.com/ivanstang/ssr-config/master/deploy_host.sh
bash ${FILE}