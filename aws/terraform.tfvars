# General AWS Configuration
aws_region          = "us-east-1"
vpc_id              = "vpc-id"
primary_subnet_id   = "subnet-id-1"
secondary_subnet_id = "subnet-id-2"

# EC2 Configuration
ami_id              = "ami-id"
default_ssh_user    = "ubuntu" # Use "ec2-user" for Amazon Linux, "ubuntu" for Ubuntu
instance_type       = "c5.4xlarge"
root_volume_size_gb = 100
ec2_instance_count  = 3
ssh_key_name        = "thirdai-platform-test-key"

# Licensing
license_file_path = "/path/to/ndb_enterprise_license.json"

# Platform Configuration
platform_admin_email    = "admin@thirdai.com"
platform_admin_username = "admin"
platform_admin_password = "password"
platform_version        = "v2.0.0"
openai_api_key          = "" # Leave blank if not using OpenAI integration

# RDS Configuration
rds_instance_class        = "db.t3.micro"
rds_master_username       = "myadmin"
rds_master_password       = "mypassword"
rds_storage_size_gb       = 20
rds_backup_retention_days = 7
rds_backup_window         = "07:00-09:00"
rds_encryption_enabled    = false # Set to true to enable encryption
rds_kms_key_id            = ""    # Leave blank if not using KMS for encryption

# EFS Configuration
efs_backup_enabled               = true
efs_encryption_enabled           = true
efs_lifecycle_policy_transition  = "AFTER_30_DAYS"
efs_performance_mode             = "generalPurpose"
efs_throughput_mode              = "bursting"
efs_provisioned_throughput_mibps = 10 # Only applicable if throughput_mode is "provisioned"

# Existing Resource Configuration (Optional)
existing_efs_id       = ""           # Provide EFS ID if reusing an existing EFS For example (fs-0e68d7c15941cc54a)
existing_rds_endpoint = ""           # Provide RDS endpoint if reusing an existing RDS For example (thirdai-platform.cjhmgr5q.us-east-1.rds.amazonaws.com:5432) with port
existing_rds_username = "myadmin"    # Required if using an existing RDS
existing_rds_password = "mypassword" # Required if using an existing RDS
