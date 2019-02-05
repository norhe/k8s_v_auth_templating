# Demonstration

One can perform the following steps from a single terminal.

## Setup

Start Vault:

```
vault server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200 -log-level=DEBUG &

```

### Minikube

Configure minikube
```
minikube start

# create namespaces
kubectl create namespace ns1
kubectl create namespace ns2

# create our service account and role binding
kubectl create serviceaccount vault-auth
kubectl create serviceaccount vault-auth --namespace="ns1"
kubectl create serviceaccount vault-auth --namespace="ns2"

kubectl apply --filename clusterRoleBinding_mod.yml 
```

### Back to Vault

```
# Set VAULT_SA_NAME to the service account you created earlier
export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")

# Set SA_JWT_TOKEN value to the service account JWT used to access the TokenReview API
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)

# Set SA_CA_CRT to the PEM encoded CA cert used to talk to Kubernetes API
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)

# Set K8S_HOST to minikube IP address
export K8S_HOST=$(minikube ip)

export VAULT_ADDR=http://localhost:8200 
vault login root

vault audit enable file file_path=/tmp/vault.log

vault auth enable kubernetes

# Notice the env vars.  These were set in the previous section.  Make sure they are present if you have multiple terminals open
vault write auth/kubernetes/config \
        token_reviewer_jwt="$SA_JWT_TOKEN" \
        kubernetes_host="https://$K8S_HOST:8443" \
        kubernetes_ca_cert="$SA_CA_CRT"

vault write auth/kubernetes/role/demo \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=* \
    policies=read_ns \
    ttl=1h

vault secrets enable -version=1 kv
vault kv put kv/default my-value=s3cr3t
vault kv put kv/ns1 my-value=s3cr3t
vault kv put kv/ns2 my-value=s3cr3t
vault kv put kv/default/test my-value=s3cr3t
vault kv put kv/ns1/test my-value=s3cr3t
vault kv put kv/ns2/test my-value=s3cr3t

KUB_MOUNT_ACCESSOR=$(vault auth list -format=json | jq -r '.["kubernetes/"].accessor') && echo $KUB_MOUNT_ACCESSOR

tee -a "read_ns.hcl" <<EOF

path "kv/{{identity.entity.aliases.$KUB_MOUNT_ACCESSOR.metadata.service_account_namespace}}/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}
EOF

vault policy write read_ns read_ns.hcl

```

### Back to Kube

```bash
kubectl run shell-demo --generator=run-pod/v1 --rm -i --tty --serviceaccount=vault-auth --image ubuntu:latest --env="VAULT_ADDR=http://$(ip route get 1 | awk '{print $NF;exit}'):8200" --namespace="ns1"

# In shell
apt-get update && apt-get install -y jq curl unzip wget less
wget https://releases.hashicorp.com/vault/1.0.2/vault_1.0.2_linux_amd64.zip -O vault.zip
unzip vault.zip && cp vault /usr/local/bin/vault
vault status

# Get our service account token
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Login
TOKEN=$(curl --request POST \
  --data '{"jwt": "'"$KUBE_TOKEN"'", "role": "demo"}' \
  $VAULT_ADDR/v1/auth/kubernetes/login | jq .auth.client_token | tr -d '"') && echo $TOKEN

vault login $TOKEN

# get our entity and namespace
ENTITY_ID=$(curl --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/auth/token/lookup-self |jq .data.entity_id | tr -d '"') && echo $ENTITY_ID

K8S_NAMESPACE=$(curl --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/auth/token/lookup-self |jq .data.meta.service_account_namespace |tr -d '"') && echo $K8S_NAMESPACE

vault kv put kv/$ENTITY_ID/test my=val
vault kv put kv/$K8S_NAMESPACE/test my=val

vault kv get kv/$ENTITY_ID/test

vault kv get kv/$K8S_NAMESPACE/test

META=$(curl --header "X-Vault-Token: $TOKEN" $VAULT_ADDR/v1/auth/token/lookup-self |jq .data.meta)

echo "$(tput setaf 3)My Metadata: $(tput setaf 3)" && echo $META |jq

