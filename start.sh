#!/bin/bash

if [ -f "deploy_host.sh"]; then
	rm "deploy_host.sh"
fi

wget https://raw.githubusercontent.com/ivanstang/ssr-config/master/deploy_host.sh
bash deploy_host.sh