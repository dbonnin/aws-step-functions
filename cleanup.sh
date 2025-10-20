#!/bin/bash

# AWS Step Functions Project Cleanup Script
# This script removes all account-specific and generated files
# while preserving infrastructure code and build scripts

echo "🧹 Starting cleanup of AWS account-specific files..."

# Remove Terraform state and cache
echo "  → Removing Terraform state files..."
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f terraform.tfstate
rm -f terraform.tfstate.backup

# Remove generated Lambda zip files
echo "  → Removing Lambda deployment packages..."
rm -f lambda.zip
rm -f lambda-service-proxy.zip

# Remove SSH keypair (will be regenerated)
echo "  → Removing SSH keypair..."
rm -f build-machine-key.pem

# Remove account-specific terraform.tfvars (keep example)
echo "  → Removing account-specific terraform.tfvars..."
rm -f terraform.tfvars

echo "✅ Cleanup complete!"
echo ""
echo "📋 Preserved files:"
echo "  ✓ Infrastructure code (*.tf files)"
echo "  ✓ Lambda source code (*.js files)"
echo "  ✓ Step Functions definitions (*.json files)"
echo "  ✓ Build machine script (create-build-machine.sh)"
echo "  ✓ Example service code"
echo "  ✓ Documentation files"
echo ""
echo "🚀 Repository is ready for fresh deployment in new AWS account!"
echo "   Next steps:"
echo "   1. Configure AWS credentials for new account"
echo "   2. Copy terraform.tfvars.example to terraform.tfvars and update values"
echo "   3. Run: terraform init"
echo "   4. Run: terraform plan"
echo "   5. Run: terraform apply"