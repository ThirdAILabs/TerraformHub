aws_region     = "us-east-1"
vpc_id         = "vpc-id"
subnet_id      = "subnet-id"
ami_id         = "ami-id"
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
rds_engine           = "postgres"
rds_engine_version   = "13.3"
rds_name             = "mydatabase"
rds_username         = "admin"
rds_password         = "mypassword"
rds_allocated_storage = 20