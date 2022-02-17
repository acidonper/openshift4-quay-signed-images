#!/bin/bash
##
# Deploy the sigstore in Openshift
##

LAB_NAME=gpgkeystore
LAB_HOME=/tmp/${LAB_NAME}
KEY_STORE=/var/lib/containers/sigstore
VERSION=$(date +%Y%m%d%H%M)

mkdir ${LAB_HOME}
sudo cp -R ${KEY_STORE} ${LAB_HOME}/
sudo cp image/Dockerfile  ${LAB_HOME}/Dockerfile

pushd ${LAB_HOME}

# build image
podman build . -t ${REPO_URL}/${REPO_USER}/${LAB_NAME}:${VERSION} 
podman login ${REPO_URL} --username ${REPO_USER} --password ${REPO_PASS} 
podman push ${REPO_URL}/${REPO_USER}/${LAB_NAME}:${VERSION}
podman tag ${REPO_URL}/${REPO_USER}/${LAB_NAME}:${VERSION} ${REPO_URL}/${REPO_USER}/${LAB_NAME}:latest
podman push ${REPO_URL}/${REPO_USER}/${LAB_NAME}:latest

# deploy
oc new-app --name=${LAB_NAME} \
  --image=${REPO_URL}/${REPO_USER}/${LAB_NAME}:${VERSION} \
  -o yaml | oc apply -f -

oc expose svc/${LAB_NAME}