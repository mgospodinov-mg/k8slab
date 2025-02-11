output "master_node_ip_addr" {
  description = "The public IP address of the master node."
  value       = aws_instance.master.public_ip
}

output "worker_node_ip_addr" {
  description = "The public IP address of the worker node."
  value       = aws_instance.worker[*].public_ip
}