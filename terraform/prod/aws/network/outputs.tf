output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_id" {
  value = module.network.public_subnet_id
}

output "private_subnet_a_id" {
  value = module.network.private_subnet_a_id
}

output "private_subnet_b_id" {
  value = module.network.private_subnet_b_id
}
