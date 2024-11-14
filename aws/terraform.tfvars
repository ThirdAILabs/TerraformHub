aws_region     = "us-east-1"
vpc_id         = "vpc-0a254f3ea6bdc3e1e"
subnet_id      = "subnet-070f76bfdc0b034d0"
ami_id         = "ami-0866a3c8686eaeeba"
default_username = "ubuntu"  # Use "ec2-user" for Amazon Linux, "ubuntu" for Ubuntu, "centos" for CentOS, etc.
instance_type  = "c5.4xlarge"
disk_size      = 100
instance_count = 2
ssh_key_name   = "thirdai-platform-test-key"
license_file_path = "/Users/yashwanthadunukota/ThirdAI-Platform/thirdai_platform/tests/ndb_enterprise_license.json"

admin_mail = "admin@thirdai.com"
admin_username = "admin"
admin_password = "password"
thirdai_platform_version = "v0.0.82"
genai_key = ""

rds_instance_class   = "db.t3.micro"
rds_engine           = "postgres"
rds_engine_version   = "13.3"
rds_name             = "mydatabase"
rds_username         = "admin"
rds_password         = "mypassword"
rds_allocated_storage = 20

efs_encrypted               = true
efs_lifecycle_transition    = "AFTER_30_DAYS"
efs_performance_mode        = "generalPurpose"
efs_throughput_mode         = "bursting"
efs_provisioned_throughput  = 10 # Only used if efs_throughput_mode is "provisioned"
