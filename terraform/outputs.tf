output "ec2-public_ip" {
  value = aws_instance.my-app-server.public_ip
}