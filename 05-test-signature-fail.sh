#!/bin/bash
##
# Tested unsigned images error
##

# Push image
podman login ${QUAY_URL} --username ${QUAY_USER} --password ${QUAY_PASS} 
podman pull registry.redhat.io/rhel8/httpd-24:latest
podman tag registry.redhat.io/rhel8/httpd-24:latest ${QUAY_URL}/${QUAY_USER}/httpd-24:latest
podman push ${QUAY_URL}/${QUAY_USER}/httpd-24:latest

# Deploy unsigned image
oc new-app --name=fail-test \
  --image=${QUAY_URL}/${QUAY_USER}/httpd-24:latest \
  -o yaml | oc apply -f -


# Print evidences
sleep 10
oc get events | grep "Failed to pull image" | grep fail-test
