variable "ct" {
  type    = string
  default = "cloudtank"
}

variable "environment" {
  type    = string
  default = "development"
}

variable "bucket_tier" {
  type        = string
  default = "cloudtank_dev"
}

variable "ia_transition_days" {
  type    = number
  default = 30
}

variable "expiration_days" {
  type    = number
  default = 365
}
