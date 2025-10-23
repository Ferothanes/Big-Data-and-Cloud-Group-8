variable "prefix_app_name" {
  type        = string
  description = "Prefix used for naming Azure resources and Docker image"
  default     = "dwhpipeline"   # <<< CHANGE this to a short unique project name
}
