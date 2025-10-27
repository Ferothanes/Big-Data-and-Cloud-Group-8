variable "prefix_app_name" {
  description = "Prefix for naming Azure resources"
  default     = "azuregroupproject" # <<< matches  repo/project name
}

variable "location" {
  type    = string
  default = "swedencentral"
}