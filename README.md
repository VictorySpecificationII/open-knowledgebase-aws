# Ignite

Every environment starts with one thing - a knowledge base.

This repository sets up a MediaWiki on AWS, along with everything that is needed (VPC, Security, etc).

# Prep

 - Run ```chmod +x fetch_public_ip.sh```


# Run

0. Decide what you want to name your wiki!

```bash
export TF_VAR_resource_prefix="INSERT YOUR NAME HERE"
```

1. Get your details from your AWS environment.

2. Set your environment variables

```bash
export AWS_REGION = "YOUR DESIRED REGION"
export AWS_ACCESS_KEY_ID="YOUR KEY ID"
export AWS_SECRET_ACCESS_KEY="YOUR ACCESS KEY"
export AWS_SESSION_TOKEN="YOUR SESSION TOKEN"
```

3. Run:
 - ```terraform init```
 - ```terraform plan```
 - ```terraform apply```

# IMPORTANT

Look at the final output, it contains IMPORTANT information.


# Tool Versions

 - Terraform: 1.9.5