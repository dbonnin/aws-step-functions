#!/bin/bash

# Script to create an EC2 build machine with Docker, Git, and Node.js
# Uses the default VPC and latest Amazon Linux AMI

set -e  # Exit on any error

# Configuration variables
INSTANCE_NAME="build-machine"
INSTANCE_TYPE="t3.medium"  # Suitable for building Docker images
KEY_NAME="${INSTANCE_NAME}-key"
SECURITY_GROUP_NAME="${INSTANCE_NAME}-sg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Creating EC2 Build Machine${NC}"
echo "=================================="

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}❌ AWS CLI is not configured or credentials are invalid${NC}"
    echo "Please run 'aws configure' first"
    exit 1
fi

# Get current AWS region
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"
    echo -e "${YELLOW}⚠️  No region configured, using default: $AWS_REGION${NC}"
fi

echo -e "${BLUE}📍 Using region: $AWS_REGION${NC}"

# Get the default VPC ID
echo -e "${BLUE}🔍 Finding default VPC...${NC}"
VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
    echo -e "${RED}❌ No default VPC found in region $AWS_REGION${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found default VPC: $VPC_ID${NC}"

# Get the first available subnet in the default VPC
echo -e "${BLUE}🔍 Finding public subnet...${NC}"
SUBNET_ID=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" --query 'Subnets[0].SubnetId' --output text)

if [ "$SUBNET_ID" = "None" ] || [ -z "$SUBNET_ID" ]; then
    echo -e "${RED}❌ No public subnet found in default VPC${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found public subnet: $SUBNET_ID${NC}"

# Get the latest Amazon Linux 2023 AMI ID
echo -e "${BLUE}🔍 Finding latest Amazon Linux AMI...${NC}"
AMI_ID=$(aws ec2 describe-images --region $AWS_REGION \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text)

if [ "$AMI_ID" = "None" ] || [ -z "$AMI_ID" ]; then
    echo -e "${RED}❌ Could not find Amazon Linux AMI${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found AMI: $AMI_ID${NC}"

# Create key pair if it doesn't exist
echo -e "${BLUE}🔑 Creating key pair...${NC}"
if aws ec2 describe-key-pairs --region $AWS_REGION --key-names $KEY_NAME &>/dev/null; then
    echo -e "${YELLOW}⚠️  Key pair '$KEY_NAME' already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws ec2 delete-key-pair --region $AWS_REGION --key-name $KEY_NAME
        echo -e "${GREEN}✅ Deleted existing key pair${NC}"
    else
        echo -e "${BLUE}ℹ️  Using existing key pair${NC}"
    fi
fi

if ! aws ec2 describe-key-pairs --region $AWS_REGION --key-names $KEY_NAME &>/dev/null; then
    aws ec2 create-key-pair --region $AWS_REGION --key-name $KEY_NAME --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 600 ${KEY_NAME}.pem
    echo -e "${GREEN}✅ Created key pair and saved to ${KEY_NAME}.pem${NC}"
fi

# Create security group if it doesn't exist
echo -e "${BLUE}🛡️  Creating security group...${NC}"
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")

if [ "$SECURITY_GROUP_ID" = "None" ] || [ -z "$SECURITY_GROUP_ID" ]; then
    SECURITY_GROUP_ID=$(aws ec2 create-security-group --region $AWS_REGION \
        --group-name $SECURITY_GROUP_NAME \
        --description "Security group for build machine" \
        --vpc-id $VPC_ID \
        --query 'GroupId' --output text)
    
    # Allow SSH access from anywhere (you may want to restrict this)
    aws ec2 authorize-security-group-ingress --region $AWS_REGION \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0
    
    echo -e "${GREEN}✅ Created security group: $SECURITY_GROUP_ID${NC}"
else
    echo -e "${YELLOW}⚠️  Security group '$SECURITY_GROUP_NAME' already exists: $SECURITY_GROUP_ID${NC}"
fi

# Create user data script
USER_DATA=$(cat << 'EOF'
#!/bin/bash
# Update system
yum update -y

# Install Git
yum install -y git

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Node.js (using NodeSource repository for latest LTS)
curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
yum install -y nodejs

# Install development tools
yum groupinstall -y "Development Tools"

# Install AWS CLI v2 (latest)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create a directory for projects
mkdir -p /home/ec2-user/projects
chown ec2-user:ec2-user /home/ec2-user/projects

# Create a startup message
cat > /etc/motd << 'MOTD_EOF'
======================================
    🚀 Build Machine Ready!
======================================
Installed software:
- Git: $(git --version)
- Docker: $(docker --version)
- Node.js: $(node --version)
- npm: $(npm --version)
- AWS CLI: $(aws --version)

Docker service is running and ec2-user is in docker group.
Project directory: ~/projects

To get started:
  cd ~/projects
  git clone <your-repo>
======================================
MOTD_EOF

# Log installation completion
echo "Build machine setup completed at $(date)" >> /var/log/build-machine-setup.log
EOF
)

# Launch EC2 instance
echo -e "${BLUE}🚀 Launching EC2 instance...${NC}"
INSTANCE_ID=$(aws ec2 run-instances --region $AWS_REGION \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --user-data "$USER_DATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Purpose,Value=BuildMachine},{Key=CreatedBy,Value=$(whoami)}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo -e "${RED}❌ Failed to create instance${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Instance created: $INSTANCE_ID${NC}"

# Wait for instance to be running
echo -e "${BLUE}⏳ Waiting for instance to be running...${NC}"
aws ec2 wait instance-running --region $AWS_REGION --instance-ids $INSTANCE_ID

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances --region $AWS_REGION --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo ""
echo -e "${GREEN}🎉 Build machine created successfully!${NC}"
echo "=================================="
echo -e "${BLUE}Instance ID:${NC} $INSTANCE_ID"
echo -e "${BLUE}Public IP:${NC} $PUBLIC_IP"
echo -e "${BLUE}Key Pair:${NC} $KEY_NAME"
echo -e "${BLUE}Private Key:${NC} ${KEY_NAME}.pem"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Wait 2-3 minutes for the instance to fully initialize"
echo "2. Connect via SSH:"
echo -e "   ${BLUE}ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP${NC}"
echo ""
echo "3. Verify installation:"
echo -e "   ${BLUE}git --version && docker --version && node --version${NC}"
echo ""
echo "4. To build Docker images, make sure to add ec2-user to docker group (already done in user data):"
echo -e "   ${BLUE}sudo usermod -a -G docker ec2-user${NC}"
echo -e "   ${BLUE}newgrp docker${NC}"
echo ""
echo -e "${YELLOW}💡 Tip:${NC} The instance is in your default VPC and has a public IP for easy access."
echo -e "${YELLOW}🛡️  Security:${NC} SSH (port 22) is open to 0.0.0.0/0. Consider restricting to your IP."
echo ""
echo -e "${RED}🧹 Cleanup:${NC} To delete everything later, run:"
echo -e "   ${BLUE}aws ec2 terminate-instances --region $AWS_REGION --instance-ids $INSTANCE_ID${NC}"
echo -e "   ${BLUE}aws ec2 delete-security-group --region $AWS_REGION --group-id $SECURITY_GROUP_ID${NC}"
echo -e "   ${BLUE}aws ec2 delete-key-pair --region $AWS_REGION --key-name $KEY_NAME${NC}"
echo -e "   ${BLUE}rm ${KEY_NAME}.pem${NC}"