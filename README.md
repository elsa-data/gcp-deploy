# elsa-data-gcp-deploy

A GCloud deployment for Elsa Data

## Dependencies

* Terraform
* A Google Cloud Platform account
* gcloud CLI
* `kubectl` CLI

## Setup

1. Run `gcloud auth login` and `gcloud auth application-default login` to login.
2. Run `gcloud config set project "${PROJECT_ID}"`, where `${PROJECT_ID}` is the project ID where you'd like to deploy Elsa.
3. Enable the Google APIs we'll be using:
   ```bash
   gcloud services enable \
     containerregistry.googleapis.com \
     sqladmin.googleapis.com \
     iam.googleapis.com
   ```
4. Run `terraform init` in the root of this repo.

## Mirror Elsa's Docker Image to a Supported Container Registry

GCP doesn't support GitHub Container Registry. Mirror it to a supported registry as follows:

```bash
# Replace these variables as needed
docker_tag=dev
gcp_project=ctrl-358804

# So that we can run docker push to push to gcr.io
gcloud auth configure-docker

docker pull "ghcr.io/umccr/elsa-data:${docker_tag}"
docker tag "ghcr.io/umccr/elsa-data:${docker_tag}" "gcr.io/${gcp_project}/elsa-data:${docker_tag}"
docker push "gcr.io/${gcp_project}/elsa-data:${docker_tag}"
```

## Create The Service Account Under Which Elsa Will Run

The following steps create a `credentials.json` file. This file contains sensitive information, which is why these steps need to be performed manually; If they were performed through Terraform, the `credentials.json` file would be stored in the `.tfstate` files which need to be committed.

```bash
PROJECT=$(gcloud config get-value project)

gcloud iam service-accounts create ${PROJECT}-account

MEMBER="${PROJECT}-account@${PROJECT}.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT" \
  --member=serviceAccount:"${MEMBER}" \
  --role=roles/cloudsql.admin

gcloud projects add-iam-policy-binding "$PROJECT" \
  --member=serviceAccount:"${MEMBER}" \
  --role=roles/secretmanager.secretAccessor

gcloud iam service-accounts keys create credentials.json \
  --iam-account="${MEMBER}"
```

## Creating Infrastructure


Check that the variables in `main.tfvars` are set correctly. Once set, run the following to create the Kubernetes cluster we'll use:

```bash
terraform apply -target=google_container_cluster.elsa_data_k8s -var-file=main.tfvars
```

Configure `kubectl` to use the newly created cluster. You might need to specify the region when running `gcloud` (e.g. by passing `--region=australia-southeast1-c`):

```bash
gcloud container clusters get-credentials elsa-data-k8s
```

Confirm that the `kubectl` can see the cluster and that it's active:

```bash
kubectl get namespaces
```

Deploy the remainder of the Elsa:

```bash
terraform apply -var apply_k8s_secrets=true -var-file=main.tfvars
```

The deployment will not work until you have set the secrets as described in the next steps. Before you set the Kubernetes secrets, it's important to prevent Terraform from continuing to manage them. Otherwise, the next time you run `terraform apply`, the secret values will be stored in the tfstate file. Prevent Terraform from managing the secrets as follows:

```bash
terraform state list | grep kubernetes_secret | xargs -L 1 terraform state rm
```

### Setting The SQL User Password

```bash
username=postgres # or whatever was set in main.tfvars
gcloud sql users set-password "${username}" --instance edgedb-postgres --prompt-for-password
```

### Setting Kubernetes Secrets

Use `kubectl edit secrets` to edit the secrets. Note that the secrets are base64-encoded. The fields you need to set are as follows:

* `edgedb_server_backend_dsn:` - The DSN of the Google Cloud SQL instance which EdgeDB uses. e.g. `postgresql://${username}:${password}@127.0.0.1:5432`, where `${username} and `${password}` are the Postgres username and password you set in previous steps.
* `instance:` - `${INSTANCE_CONNECTION_NAME}=tcp:5432`, where `${INSTANCE_CONNECTION_NAME}` is the connection name of the Google Cloud SQL instance which EdgeDB uses. You can find this using `gcloud sql instances describe edgedb-postgres --format="value(connectionName)"`.
* `credentials.json:` - The contents of the `credentials.json` which you created in previous steps. (Again, you should ensure this is base64-encoded.)
* `edgedb_server_tls_cert:` and `edgedb_server_tls_key:` - These are the certificate and key referred to [here](https://www.edgedb.com/docs/guides/deployment/gcp). Elsa can only communicate to the EdgeDB instance within the Kubernetes pod, so self-signed ceritificates are good enough.
* `edgedb_server_password:` - The password you would like to set for the `edgedb` user on the EdgeDB server.
* `edgedb_dsn:` - `edgedb://edgedb:${password}@localhost`, where `${password}` is the password for the `edgedb` user.

👉 **Important** - `edgedb_server_password` is only used when the `edgedb` container successfully connects to the Postgres database for the very first time. The `edgedb_server_password` is used to _set_ the password, but not to _update_ it. If the password has already been set, one (destructive) way to update the password would be to destroy the Postgres instance and create it again.

### Setting GCP Secrets

1. ```bash
   vim /tmp/conf.json
   ```

2. Enter a secret like the following:
   ```json
   {
     "oidc.issuerUrl": "https://test.cilogon.org",
     "oidc.clientId": "change me",
     "oidc.clientSecret": "change me",
     "rems.botUser": "change me",
     "rems.botKey": "change me"
   }
   ```

3. ```bash
   gcloud secrets versions add ElsaDataDevDeployed --data-file=/tmp/conf.json
   ```

4. ```bash
   rm /tmp/conf.json
   ```

### Reading The New Secret Values

After setting the secrets, restart the Kubernetes pod by running:

```
kubectl rollout restart deployment elsa-data
```

This might take a few minutes. You can check the status of the update by running `kubectl get pods` periodically:

```
$ watch -n0.2 kubectl get pods
NAME                         READY   STATUS    RESTARTS      AGE
elsa-data-585cc897b6-8trnk   2/3     Running   0             36s
elsa-data-5c76f6cb75-87ljq   3/3     Running   1 (24m ago)   24m
```

Eventually, once the restart has completed, you should see only one pod:

```
NAME                         READY   STATUS    RESTARTS      AGE
elsa-data-585cc897b6-8trnk   3/3     Running   0             50s
```

## Checking That The Deployment Works

After you've run `terraform apply` as described in the previous steps, it can take about 15 minutes or more for the deployment to become available, even after the Kubernetes pod is ready. This is because the deployment adds DNS entries and provisions a TLS certificate.

If you're using Google's public DNS (i.e. `8.8.8.8` and `8.8.4.4`), you can request it to clear its cache [here](https://dns.google/cache).

You can also check the status of the TLS certificate by running `kubectl describe managedcertificate managed-cert`. The output should contain the line `Certificate Status: Active` once it's ready.

After enough waiting, Elsa should eventually be accessible through your web browser at the FQDN you specified in the tfvars file. By default this is [https://elsa-data-dev.dsp.garvan.org.au](https://elsa-data-dev.dsp.garvan.org.au). If it hasn't become available, the following commands are useful for viewing the status of the pod and checking logs:

```bash
kubectl get pods
kubectl logs "${pod_name}"
kubectl logs "${pod_name}" -c "${container_name}"
```

## Running Migrations

Migrations currently need to be run manually, but it'd be nice to have an automated way to perform them in the future. For now, migrations can be performed by following these steps:

1. Run an EdgeDB server locally, using the remote Postgres instance:

   ```bash
   postgres_hostname=34.87.242.71 # change me
   password=password # change me
   docker run -it \
     -p 5656:5656 \
     -e EDGEDB_SERVER_SECURITY=insecure_dev_mode \
     -e EDGEDB_SERVER_BACKEND_DSN=postgresql://postgres:${password}@${postgres_hostname}:5432 \
     edgedb/edgedb
   ```

   Note that you might need to change the network settings of the Postgres instance to allow connections from non-Google IP addresses. You can do this using the `gcloud` CLI or console.

2. In the `application/backend` directory of the [elsa-data](https://github.com/umccr/elsa-data/) repo, run:

   ```bash
   EDGEDB_DSN=edgedb://edgedb:${password}@localhost edgedb migrate
   ```
