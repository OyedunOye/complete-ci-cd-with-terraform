variable "region"{
    default = "us-east-1"
}
variable "vpc_cidr_block" {
    default = "10.0.0.0/16"
}
variable "subnet_cidr_block" {
    default = "10.0.10.0/24"
}
variable "avail_zone" {
    default = "us-east-1a"
}
variable "env_prefix" {
    default = "dev"
}
variable "my_ip_address" {
    default = "93.159.0.0/16"
}
variable "jenkins_ip_address" {
    default = "178.105.179.238/32"
}
variable "instance_type" {
    default = "t2.micro"
}