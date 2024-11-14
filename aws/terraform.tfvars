aws_region     = "us-east-1"
vpc_id         = "vpc-id"
subnet_id_1    = "subnet-id-1"
subnet_id_2    = "subnet-id-2" # In different sub region under same aws region (required for RDS)
ami_id         = "ami-id"
default_username = "ubuntu"  # Use "ec2-user" for Amazon Linux, "ubuntu" for Ubuntu, "centos" for CentOS, etc.
instance_type  = "c5.4xlarge"
disk_size      = 100
instance_count = 2
ssh_key_name   = "neuraldb-enterprise-key"
license_file_path = "/path/to/ndb_enterprise_license.json"
admin_mail = "admin@main.com"
admin_username = "admin"
admin_password = "password"
thirdai_platform_version = "v0.0.82"
genai_key = ""

rds_instance_class   = "db.t3.micro"
rds_username         = "myadmin"
rds_password         = "mypassword"
rds_allocated_storage = 20

efs_encrypted               = true
efs_lifecycle_transition    = "AFTER_30_DAYS"
efs_performance_mode        = "generalPurpose"
efs_throughput_mode         = "bursting"
efs_provisioned_throughput  = 10 # Only used if efs_throughput_mode is "provisioned"
