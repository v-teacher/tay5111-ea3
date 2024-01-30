#!/bin/bash

# Configura las credenciales de AWS
#export AWS_ACCESS_KEY_ID="TU_ACCESS_KEY_ID"
#export AWS_SECRET_ACCESS_KEY="TU_SECRET_ACCESS_KEY"
#export AWS_DEFAULT_REGION="us-east1"

AWS_REGION="us-east1"

# Obtener el VPC ID de la VPC "default"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)

#Crear Security Groups
aws ec2 create-security-group --group-name SG-Linux --description "Security Group for Linux instances" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=SG-Linux}]'
aws ec2 create-security-group --group-name SG-EFS --description "Security Group for EFS" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=SG-EFS}]'
aws ec2 create-security-group --group-name SG-ALB --description "Security Group for Application Load Balance" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=SG-ALB}]'


#Almacenar SG_ID
SG_Linux_ID=$(aws ec2 describe-security-groups --group-names SG-Linux --query 'SecurityGroups[*].GroupId' --output text)
SG_EFS_ID=$(aws ec2 describe-security-groups --group-names SG-EFS --query 'SecurityGroups[*].GroupId' --output text)
SG_ALB_ID=$(aws ec2 describe-security-groups --group-names SG-ALB --query 'SecurityGroups[*].GroupId' --output text)


#Reglas SG-Linux
aws ec2 authorize-security-group-ingress --group-name SG-Linux --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name SG-Linux --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name SG-Linux --protocol tcp --port 80 --source-group $SG_ALB_ID
aws ec2 authorize-security-group-ingress --group-name SG-Linux --protocol tcp --port 2049 --source-group $SG_EFS_ID

#Reglas SG-EFS
aws ec2 authorize-security-group-ingress --group-name SG-EFS --protocol tcp --port 2049 --source-group $SG_Linux_ID

#Reglas SG-ALB
aws ec2 authorize-security-group-ingress --group-name SG-ALB --protocol tcp --port 80 --cidr 0.0.0.0/0


#Crear bucket de S3

BUCKET_NAME="tay5111"

aws s3api create-bucket --bucket $BUCKET_NAME
aws s3api put-public-access-block \
--bucket  $BUCKET_NAME \
--public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://policy.json

aws s3 cp index.php s3://tay5111/




