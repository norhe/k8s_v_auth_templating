# v1
# Incorrect.  Metadata supplied by authentication are added to alias metadata.  Have to get the auth mount accessor like in 
# the readme, line 74-81
path "kv/{{identity.entity.metadata.service_account_namespace}}/*" {
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