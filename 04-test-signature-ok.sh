#!/bin/bash
##
# Tested unsigned images works
##

# Deploy unsigned image
oc new-app --name=ok-test \
  --image=${DEST_IMAGE} \
  -o yaml | oc apply -f -


# Print evidences
sleep 10
oc get po | grep ok-test
