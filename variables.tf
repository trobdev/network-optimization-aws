# --- root/variables.tf ---
variable "vpc_count" {
    default = 2
}

variable "azs" {
    default = ["us-east-1a", "us-east-1b"]
}