# v1
path "kv/{{identity.entity.metadata.service_account_namespace}}/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

path "kv/{{identity.entity.metadata.service_account_namespace}}" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

path "kv/{{identity.entity.id}}" {
  capabilities = ["create", "update", "read", "delete", "list"]
}
path "kv/{{identity.entity.id}}/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

#path "kv/ns1/*" {
#  capabilities = ["create", "update", "read", "delete", "list"]
#}