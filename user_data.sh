#!/bin/bash

yum install -y httpd php wget
systemctl start httpd
systemctl enable httpd


sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-0e441f7ed3d4fa1b9.efs.us-east-1.amazonaws.com:/ /var/www/html

sudo wget -nc https://tay5111.s3.amazonaws.com/index.php -P /var/www/html/
