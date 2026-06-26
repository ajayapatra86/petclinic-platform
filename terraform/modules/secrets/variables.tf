variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API key for genai-service (sensitive)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
