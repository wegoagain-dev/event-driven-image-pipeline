# Event-Driven Image Pipeline

This project demonstrates an event driven image pipeline that when a user uploads an image to an s3 bucket, a lambda function will create a thumbnail and extract metadata from the image and send to another s3 bucket. Another lambda function will pull this from the SQS queue and metadata will be stored in a DynamoDB table. Any failed jobs will be in a separate queue (DLQ) which can be checked manually. We will also set up a Cloudwatch alarm if the DLQ receives any messages.

## 🏗 Architecture
![arch](/images/event-driven-image-pipeline.svg)

## What is event-driven Architecture?
Event-driven architecture is a design pattern where events trigger actions in the system, instead of services calling through each other they can communicate through events.

## What is S3(simple storage service)?
Object storage service (store files in the cloud)
S3 events can trigger lambda functions

## What is Lambda?
Run code without managing servers

## What is SQS?
Managed message queue service\
Dead Letter Queue (DLQ): Where failed messages go

![](/images/img-1.png)

## What is DynamoDB?
NoSQL database (key-value and document store)

## What is Serverless? (Not Actually Serverless 😄)
- Servers still exist
- You just don't manage them
- Provider handles: provisioning, scaling, patching\
Good for (event-driven workloads, variable traffic, microservices, rapid development)\
Bad for (long-processes(15min), predictable constant load, websockets(fargate better), large files processing(use ECS))

---
***Events*** - something that happens in the past (user uploaded an image)\
***Producers*** - services that generate events (s3 produces upload event)\
***Consumers*** - services that respond to events (lambda functions)\
***Queues*** - middleware that routes events, services that store events (SQS)

---

## Design Decisions
1. Why SQS is used between lambda functions
   - Decoupling: If DynamoDB is temporarily down, messages queue up instead of failing.
   - Retry logic: SQS automatically retries failed messages.
   - Asynchronous processing: Image processing doesnt wait for DB writes.
2. Why two lambda functions?
   - Single Responsibility: Each function has one job
   - Independent scaling: image processing and DB writes scale seperately.
   - Easier debugging and cost efficient
3. Why DLQ:
   - Resilience: Failed messages arent lost
   - Monitoring: Alerts on failures
   - Manual review: Investigate problematic images

---

## Requirements
- Terraform 
- AWS CLI
- Python 3.11
- Git

### How to run this project

```bash
git clone https://github.com/wegoagain-dev/event-driven-image-pipeline.git
cd terraform
```

### Install lambda dependencies
you will need to install the dependencies for each lambda function, as lambda functions are deployed as zip files which arent packaged with code

cd into each directory and run the docker command (it ensures you install them with python 3.11)

```bash
cd image_processor

docker run --rm -v "$(pwd)":/var/task -w /var/task \
  --platform linux/amd64 \
  --entrypoint pip \
  public.ecr.aws/lambda/python:3.11 \
  install -r requirements.txt -t .
```

```bash
cd db_writer

docker run --rm -v "$(pwd)":/var/task -w /var/task \
  --platform linux/amd64 \
  --entrypoint pip \
  public.ecr.aws/lambda/python:3.11 \
  install -r requirements.txt -t .
```

Our project has variables set in `terraform/variables.tf`. These variables can be customised for your project by modifying `terraform.tfvars.example` and renaming it to `terraform.tfvars`.

### Run the code 
go to the terraform directory:

```bash
# Initialize Terraform
terraform init
# Preview changes
terraform plan
# Deploy
terraform apply
# Save outputs (optional)
terraform output > outputs.txt
# When finished, destroy the infrastructure
terraform destroy
```

---

## Useful Commands
(if commands dont work copy the name and paste instead of the function name)

### Upload file
aws s3 cp <your-photo-image> s3://$(terraform output -raw upload_bucket_name)/

### Check thumbnail creation  
aws s3 ls s3://$(terraform output -raw thumbnail_bucket_name)/thumbnails/

### View Lambda logs
aws logs tail /aws/lambda/$(terraform output -raw image_processor_function_name) --follow

### Scan DynamoDB
aws dynamodb scan --table-name $(terraform output -raw dynamodb_table_name)

### Open dashboard
`open $(terraform output -raw dashboard_url)`  # Mac\
`xdg-open $(terraform output -raw dashboard_url)`  # Linux

---

## Troubleshooting
Common Issues
1. Lambda Timeout
Symptom: Lambda times out after 60 seconds
Solutions:
- Increase timeout in `lambda.tf`
- Optimize image processing
- Increase memory (more CPU)

2. Out of Memory
Symptom: Lambda crashes with "Runtime exited with error"
Solutions:
- Increase memory allocation
- Process smaller batches

3. DynamoDB Throttling
Symptom: ProvisionedThroughputExceededException
Solutions:
- Switch to on-demand billing
- Increase provisioned capacity
- Implement exponential backoff

4. SQS Message Stuck
Symptom: Messages remain in queue
Solutions:
- Check Lambda event source mapping
- Verify IAM permissions
- Check visibility timeout

5. S3 Trigger Not Working
Symptom: Lambda not invoked on upload
Solutions:
- Verify S3 event notification configuration
- Check Lambda permission for S3
- Ensure file extension matches filter

---

# What im working on adding next
- Set up SNS topic for alarm notifications
- Add github integration
- API Gateway for direct uploads
