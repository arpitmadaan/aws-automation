variable "instance_names" {
  type = list(string)
}

variable "aws_profile" {
  type    = string
  default = "default"  # Replace with your desired profile name if you want to hard-code it
}
