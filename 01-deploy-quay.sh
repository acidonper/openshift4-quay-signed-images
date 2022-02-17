#!/bin/bash
##
# Deploy Quay Server
##

cat <<EOF | oc apply -f -
apiVersion: quay.redhat.com/v1
kind: QuayRegistry
metadata:
  name: registry
spec:
  configBundleSecret: init-config-bundle-secret
EOF
