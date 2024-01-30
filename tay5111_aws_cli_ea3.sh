#!/bin/bash

# Configura las credenciales de AWS
#export AWS_ACCESS_KEY_ID="TU_ACCESS_KEY_ID"
#export AWS_SECRET_ACCESS_KEY="TU_SECRET_ACCESS_KEY"
#export AWS_DEFAULT_REGION="us-east1"

AWS_REGION="us-east-1"

# Obtener el VPC ID de la VPC "default"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text)


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

cat <<EOF > policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$(echo $BUCKET_NAME)/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://policy.json
aws s3 cp index.php s3://tay5111/

# EFS

aws efs create-file-system \
    --creation-token token \
    --tags Key=Name,Value=webserver_EFS \
    --performance-mode generalPurpose \
    --throughput-mode bursting \
    --encrypted \
    --region us-east-1 \

FILE_SYSTEM_ID=$(aws efs describe-file-systems --query "FileSystems[?Name=='webserver_EFS'].FileSystemId" --output text)

for SUBNET_ID in $SUBNET_IDS; do
    aws efs create-mount-target \
    --file-system-id $FILE_SYSTEM_ID \
    --subnet-id $SUBNET_ID \
    --security-groups $SG_EFS_ID
done


echo "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $(echo $FILE_SYSTEM_ID).efs.us-east-1.amazonaws.com:/ /var/www/html"

# Creacion de archivo user_data

cat <<EOF > user_data.sh
#!/bin/bash

yum install -y httpd php wget
systemctl start httpd
systemctl enable httpd


sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $(echo $FILE_SYSTEM_ID).efs.us-east-1.amazonaws.com:/ /var/www/html

sudo wget -nc https://tay5111.s3.amazonaws.com/index.php -P /var/www/html/
EOF

#AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=imageid,Values=ami-0a3c3a20c09d6f377" --query "Images[0].ImageId" --region $AWS_REGION --output text)
AMI_ID="ami-0a3c3a20c09d6f377"

# Obtener el ID de la subred en la zona de disponibilidad "us-east-1a"
SUBNET_ID_A=$(aws ec2 describe-subnets --filters "Name=availability-zone,Values=us-east-1a" --query "Subnets[0].SubnetId" --output text)

# Obtener el ID de la subred en la zona de disponibilidad "us-east-1b"
SUBNET_ID_B=$(aws ec2 describe-subnets --filters "Name=availability-zone,Values=us-east-1b" --query "Subnets[0].SubnetId" --output text)

# Obtener el ID de la subred en la zona de disponibilidad "us-east-1c"
SUBNET_ID_C=$(aws ec2 describe-subnets --filters "Name=availability-zone,Values=us-east-1c" --query "Subnets[0].SubnetId" --output text)

# Crear un array con los IDs de las subredes en cada zona de disponibilidad
SUBNET_IDS=("$SUBNET_ID_A" "$SUBNET_ID_B" "$SUBNET_ID_C")
AZ=("us-east-1a" "us-east-1b" "us-east-1c")
i=0

for SUBNET_ID in "${SUBNET_IDS[@]}"; do
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type t2.micro \
        --security-group-ids $SG_Linux_ID \
        --subnet-id $SUBNET_ID \
        --associate-public-ip-address \
        --user-data file://user_data.sh \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=webserver-${AZ[$i]}}]" \
        --placement AvailabilityZone=$(aws ec2 describe-subnets --subnet-ids $SUBNET_ID --query "Subnets[0].AvailabilityZone" --output text) \
        --query "Instances[0].InstanceId" \
        --output text \
        --region $AWS_REGION)
    ((i++))
done

# ALB


