environment          = "dev"
project_name         = "oyd-project"
region               = "us-east-1"
app_bucket_prefix    = "app-assets"
db_username          = "admin"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
single_nat_gateway   = true
health_check_path    = "/"

queue_name_prefix             = "spvr-jobs"
visibility_timeout_seconds    = 60
message_retention_seconds     = 86400
max_receive_count             = 3
dlq_message_retention_seconds = 1209600

batch_size                         = 3
maximum_batching_window_in_seconds = 0
bisect_batch_on_function_error     = true

schedule_expression = "rate(1 hour)"
scheduler_timezone  = "America/Guatemala"
stale_hours         = 2
api_domain_name     = "api.grupo1.oyd.solid.com.gt"

alarm_notification_email = "sandra.soria@galileo.edu"
root_domain_name         = "grupo1.oyd.solid.com.gt"
create_dns_zone          = true
hosted_zone_id           = null