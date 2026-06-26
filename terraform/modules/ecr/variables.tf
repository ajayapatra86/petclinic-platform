variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
}

variable "service_names" {
  description = "List of service names — one ECR repository is created per service"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "Tag mutability: MUTABLE for dev, IMMUTABLE for prod"
  type        = string
  default     = "MUTABLE"
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
