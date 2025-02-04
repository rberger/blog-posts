#!/usr/bin/env sh

/opt/bitnami/ctlscript.sh stop
/opt/bitnami/letsencrypt/lego --tls --email="rberger@ibd.com" --domains="www.ibd.com" --path="/opt/bitnami/letsencrypt" renew --days 90
/opt/bitnami/ctlscript.sh start
