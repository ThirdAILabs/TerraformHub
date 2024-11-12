terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "6.11.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.0"
    }
  }
}