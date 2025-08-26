output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets."
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets."
  value       = module.vpc.public_subnets
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host."
  value       = aws_instance.bastion.public_ip
}

output "kafka_broker_private_ips" {
  description = "Private IP addresses of the Kafka brokers."
  value       = aws_instance.kafka_broker.*.private_ip
}

output "airflow_public_ip" {
  description = "Public IP address of the Airflow server."
  value       = aws_instance.airflow.public_ip
}

output "airflow_private_ip" {
  description = "Private IP address of the Airflow server."
  value       = aws_instance.airflow.private_ip
}