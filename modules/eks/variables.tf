variable "project" { type = string }
variable "environment" { type = string }

variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "endpoint_public_access" {
  type        = bool
  description = "Akses API server dari internet (mudah untuk belajar; matikan di prod)"
  default     = true
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public API endpoint. Leaving this open to the world is the single most common EKS misconfiguration."
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  type        = list(string)
  description = "Control plane logs shipped to CloudWatch. The audit log is what an incident investigation actually reads."
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "cluster_addons" {
  type        = map(string)
  description = "Managed addon name to version. Empty string means the default version for the cluster."
  default = {
    vpc-cni            = ""
    coredns            = ""
    kube-proxy         = ""
    aws-ebs-csi-driver = ""
  }
}

variable "kms_key_arn" {
  type        = string
  description = "CMK used to encrypt the control plane log group. Cluster secrets use a dedicated key created in this module."
  default     = null
}
