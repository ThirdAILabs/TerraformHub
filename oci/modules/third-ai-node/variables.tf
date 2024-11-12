# modules/third-ai-node/variables.tf

variable "compartment_id" {
  description = "OCID of the compartment where the instance will be created"
  type        = string
}

variable "availability_domain" {
  description = "The availability domain where the instance will be created"
  type        = string
}

variable "subnet_id" {
  description = "OCID of the subnet where the instance will be created"
  type        = string
}

variable "ssh_public_key" {
  description = "The public SSH key for accessing the instance"
  type        = string
}

variable "instance_name" {
  description = "Name of the instance"
  type        = string
}

variable "vnic_name" {
  description = "Name of the VNIC"
  type        = string
}

variable "nsg_ids" {
  description = "List of Network Security Group OCIDs to associate with the instance"
  type        = list(string)
  default     = []
}