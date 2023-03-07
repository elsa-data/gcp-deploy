# elsa-data-gcp-deploy

A GCloud deployment for Elsa Data

## Dependencies

* Terraform
* A Google Cloud Platform account
* gcloud CLI

## Setup

1. Run `gcloud auth login` and `gcloud auth application-default login` to login.
2. Run `terraform init` in the root of this repo.

## Mirror Elsa's Docker Image to a Supported Container Registry

GCP doesn't support GitHub Container Registry. Mirror it to a supported registry as follows:

```bash
# Replace these variables as needed
tag=dev
gcp_project=ctrl-358804

# So that we can run docker push to push to gcr.io
gcloud auth configure-docker

docker pull "ghcr.io/umccr/elsa-data:${tag}"
docker tag "ghcr.io/umccr/elsa-data:${tag}" "gcr.io/${gcp_project}/elsa-data:${tag}"
docker push "gcr.io/${gcp_project}/elsa-data:${tag}"
```

## Creating Infrastructure

Check that the variables in `main.tfvars` are correctly set. Once they're set, create the necessary secrets:

```terraform
terraform apply \
  -target=google_secret_manager_secret.elsa_data_dev_deployed \
  -target=google_secret_manager_secret.root_ca_crt \
  -target=google_secret_manager_secret.edgedb_dsn \
  -var-file=main.tfvars
```

Once the secrets have been created, they must be manually set in Google Cloud Platform. This can be done either by using the CLI or the console. Once the secrets are in place, the remaining infrastructure can be created with the following command:

```terraform
terraform apply -var-file=main.tfvars
```
