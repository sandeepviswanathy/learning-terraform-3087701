output "instance_ami" {
  value = aws_instance.blog_ysani.ami
}

output "instance_arn" {
  value = aws_instance.blog_ysani.arn
}

output "instance_public_dns" {
  value = aws_instance.blog_ysani.public_dns
}