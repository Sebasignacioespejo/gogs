docker-build:
	docker build -t gogs .

generate-tfvars-aws:
	@echo 'ec2_ami = "$(EC2_AMI)"' > terraform/prod/aws/ec2/terraform.tfvars
	@echo 'ec2_key_name = "$(EC2_KEY_NAME)"' >> terraform/prod/aws/ec2/terraform.tfvars
	@echo 'control_ip = "$(CONTROL_IP)"' >> terraform/prod/aws/ec2/terraform.tfvars
	@echo 'agent_ip = "$(AGENT_IP)"' >> terraform/prod/aws/ec2/terraform.tfvars

	@echo 'db_user = "$(DB_USER)"' > terraform/prod/aws/rds/terraform.tfvars
	@echo 'db_password = "$(DB_PASSWORD)"' >> terraform/prod/aws/rds/terraform.tfvars
	@echo 'db_name = "$(DB_NAME)"' >> terraform/prod/aws/rds/terraform.tfvars

generate-tfvars-azure:
	@echo 'control_ip = "$(CONTROL_IP)"' > terraform/prod/azure/network/terraform.tfvars
	@echo 'agent_ip = "$(AGENT_IP)"' >> terraform/prod/azure/network/terraform.tfvars

	@echo 'db_user = "$(DB_USER)"' > terraform/prod/azure/db/terraform.tfvars
	@echo 'db_password = "$(DB_PASSWORD)"' >> terraform/prod/azure/db/terraform.tfvars
	@echo 'db_name = "$(DB_NAME)"' >> terraform/prod/azure/db/terraform.tfvars

	@echo 'vm_key_name = "$(VM_KEY_NAME)"' > terraform/prod/azure/vm/terraform.tfvars

infra-aws:
	cd terraform/prod/aws/network && terraform init && terraform apply -auto-approve
	cd terraform/prod/aws/ec2 && terraform init && terraform apply -auto-approve
	cd terraform/prod/aws/rds && terraform init && terraform apply -auto-approve
	cd terraform/prod/aws/security-rules && terraform init && terraform apply -auto-approve

	cd terraform/prod/aws/ec2 && terraform output -raw ec2_public_ip > ../../../../SERVER_IP.txt
	cd terraform/prod/aws/rds && terraform output -raw rds_endpoint > ../../../../DB_ENDPOINT.txt

infra-azure:
	cd terraform/prod/azure/network && terraform init && terraform apply -auto-approve
	cd terraform/prod/azure/vm && terraform init && terraform apply -auto-approve
	cd terraform/prod/azure/db && terraform init && terraform apply -auto-approve

	cd terraform/prod/azure/network && terraform output -raw vm_ip > ../../../../SERVER_IP.txt
	cd terraform/prod/azure/db && terraform output -raw db_endpoint > ../../../../DB_ENDPOINT.txt

generate-app-config:
	$(eval SERVER_IP=$(shell cat SERVER_IP.txt))
	$(eval DB_ENDPOINT=$(shell cat DB_ENDPOINT.txt))

	@echo 'RUN_MODE = prod' > app.ini
	@echo 'RUN_USER = root' >> app.ini
	@echo '' >> app.ini
	@echo '[server]' >> app.ini
	@echo "EXTERNAL_URL = http://${SERVER_IP}:3000" >> app.ini
	@echo "DOMAIN = ${SERVER_IP}" >> app.ini
	@echo '' >> app.ini
	@echo '[database]' >> app.ini
	@echo "HOST = ${DB_ENDPOINT}" >> app.ini
	@echo "USER = ${DB_USER}" >> app.ini
	@echo 'PASSWORD = `${DB_PASSWORD}`' >> app.ini
	@echo 'SSL_MODE = require' >> app.ini
	@echo '' >> app.ini
	@echo '[security]' >> app.ini
	@echo 'INSTALL_LOCK = true' >> app.ini

save-docker-image:
	@mkdir -p docker-image
	docker save -o docker-image/gogs.tar gogs

configure:
	$(eval SERVER_IP=$(shell cat SERVER_IP.txt))

	ansible-galaxy collection install signalfx.splunk_otel_collector
	
	cd ansible && ANSIBLE_HOST_KEY_CHECKING=False \
	ansible-playbook -i "$(SERVER_IP)," playbook.yml -u ubuntu \
	--extra-vars "host_ip=$(SERVER_IP)" \
	--private-key $(KEY)

generate-backup-ips:
	cd terraform/prod/aws/ec2 && terraform init && terraform output -raw ec2_public_ip > ../../../../EC2_IP.txt
	cd terraform/prod/azure/network && terraform init && terraform output -raw vm_ip > ../../../../VM_IP.txt

create-backup:
	$(eval SERVER_IP=$(shell cat EC2_IP.txt))

	@mkdir -p backup

	cd ansible && ANSIBLE_HOST_KEY_CHECKING=False \
	ansible-playbook -i "$(SERVER_IP)," backup.yml -u ubuntu \
	--extra-vars "host_ip=$(SERVER_IP)" \
	--private-key $(KEY)

recover-backup:
	$(eval SERVER_IP=$(shell cat VM_IP.txt))
	$(eval BACKUP_FILE=$(shell ls backup/*.zip))

	cd ansible && ANSIBLE_HOST_KEY_CHECKING=False \
	ansible-playbook -i "$(SERVER_IP)," recover.yml -u ubuntu \
	--extra-vars "host_ip=$(SERVER_IP)" \
	--extra-vars "backup_file_name=$(BACKUP_FILE)" \
	--private-key $(KEY)

clean:
	docker system prune -af --volumes