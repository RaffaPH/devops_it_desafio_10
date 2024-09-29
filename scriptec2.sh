#!/bin/bash

#Recursos
NAME="desafio10"
AMI="ami-0e86e20dae9224db8"
INSTANCE_TYPE="t2.micro"
KEY=""
VPC=""
REGION="us-east-1"
AZ="us-east-1a"
SUBNET=""
SG_ID=""
USER_DATA_APACHE="user_data_desafio10.txt"
PROFILE="awslabs"
S3=""


#Create S3
echo "Creando S3..: "
S3=$(aws s3api create-bucket \
    --bucket $NAME \
    --region $REGION
    --profile $PROFILE)
    
BUCKET=$(echo "$S3" | jq -r '.Location')

echo "Subiendo script a S3..: "
aws s3 cp script_format_volume.sh s3://$BUCKET/ --recursive --profile $PROFILE


#create-volume
echo "Creando Volume (EBS)..: "
VOLUME=$(aws ec2 create-volume --volume-type gp2 --size 2 --availability-zone $AZ --profile $PROFILE)
VOLUME_ID=$(echo "$VOLUME" | jq -r '.VolumeId')

#create-key-pair:
echo "Creando Keys: "
KEY=$(aws ec2 create-key-pair --key-name $NAME --profile $PROFILE)


#create security-group:
echo "Creando Security Group: "
SG_ID=$(aws ec2 create-security-group --group-name $NAME --description "$NAME" --profile $PROFILE)

#create ingress rules:
echo "Reglas de entrada configuradas para el grupo de seguridad"
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --profile $PROFILE 
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --profile $PROFILE
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --profile $PROFILE

#create egress rules:
echo "Reglas de salida configuradas para el grupo de seguridad"
aws ec2 authorize-security-group-egress --group-id $SG_ID --protocol tcp --port 0-65535 --cidr 0.0.0.0/0 --profile $PROFILE
#aws ec2 authorize-security-group-egress --group-id $SG_ID --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=10.0.0.0/16}]'

#run-instances:
echo "Creando Instancias EC2...: "
INSTANCE=$(aws ec2 run-instances \
    --image-id $AMI \
    --instance-type $INSTANCE_TYPE \
    --count 1 \
    --key-name $KEY \
    --placement AvailabilityZone=$AZ
    --security-group-ids $SG_ID \
#    --subnet-id $SUBNET \
#    --associate-public-ip-address \
    --user-data file://$USER_DATA \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Owner,Value=Sebastian Herrera}, {Key=Team,Value=Grupo1}, {Key=Email,Value=sebastian.herrera@mycompany.com}, {Key=Proyectogrupo-1,Value=Actividad-AWS}]'\
    --profile $PROFILE)


INSTANCE_ID=$(echo "$INSTANCE" | jq -r '.InstanceId')

#attach-volume

aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device /dev/sdf

# ELIMINAR RECURSOS
echo "Iniciando proceso de eliminación de recursos..."

# Detach volume
echo "Desconectando volumen..."
aws ec2 detach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --profile $PROFILE

# Delete instance
echo "Eliminando instancia..."
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --profile $PROFILE

# Delete security group
echo "Eliminando grupo de seguridad..."
aws ec2 delete-security-group --group-id $SG_ID --profile $PROFILE

# Delete key pair
echo "Eliminando coppia de claves..."
aws ec2 delete-key-pair --key-name $NAME --profile $PROFILE

# Delete S3 bucket
echo "Eliminando bucket S3..."
aws s3 rb s3://$BUCKET --force --profile $PROFILE

echo "Proceso de eliminación de recursos completado."