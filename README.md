# Signed Container Images in Openshift

This repository tries to collect the required information and resources to deploy container images securing strategy in Openshift. 

This integration is based on Red Hat Openshift and Red Hat Quay using GPG2.

## Prerequisites

- Red Hat Openshift Cluster +4.9
- OC Client installed
- gpg2 installed
- A external image repository to save the sigstore container image

## Settings Up the solution

During the following sections a set of procedures are included for implementing a signed container images strategy in Openshift based on Red Hat Quay and GPG Keys.

### GPG2 Keys Store

First at all, it is required to generate a GPG key for signing the images. It is important to bear in mind that the approach is having a unique GPG key for signing all the different container images and create a repository to save the signature generated for every container image.

The following procedure includes the basic steps to create a GPG Key:

- Generate gpg2 key

```$bash
gpg2 --gen-key
```

- Extract gpg2 pub key

```$bash
gpg2 --armor --export gpguser@email.com > gpgkey.pub
```

### Install Red Hat Quay

In order to save the signed images, it is required to deploy an image registry. Red Hat Quay is a private container registry that stores, builds, and deploys container images. It analyzes your images for security vulnerabilities, identifying potential issues that can help you mitigate security risks.

The following procedure includes the basic steps to install Red Hat Quay in Openshift:

- Install Red Hat Quay Operator in Openshift (*OpenShift console, Select Operators → OperatorHub, then select the Red Hat Quay Operator.*)

- Create a specific namespace

```$bash
oc new-project quay
```

- Create S3 object management service account secret in Openshift

```$bash
export AWS_ACCESS_KEY_ID='xxxx'
export AWS_SECRET_ACCESS_KEY='xxxx'
export AWS_S3_API=s3.us-east-2.amazonaws.com
export AWS_S3_BUCKET=quay

sh 00-generate-quay-config.sh
```

- Deploy Red Hat Quay

```$bash
sh 01-deploy-quay.sh

oc get pods
NAME                                         READY   STATUS             RESTARTS        AGE
...
registry-quay-app-6f7d94c744-sxvh6           1/1     Running            0               24m
registry-quay-app-6f7d94c744-xchcm           1/1     Running            0               24m
registry-quay-app-upgrade--1-gx958           0/1     Completed          0               24m
registry-quay-config-editor-df5bc754-562pr   1/1     Running            0               24m
registry-quay-database-6fffbdcc7-qxmts       1/1     Running            0               25m
registry-quay-mirror-7f68fd5f9d-98w5s        1/1     Running            0               23m
registry-quay-mirror-7f68fd5f9d-9mdp4        1/1     Running            0               23m
registry-quay-postgres-init--1-qxr9c         0/1     Completed          0               24m
registry-quay-redis-6d7df7cfb-5pb25          1/1     Running            0               25m
```

- Initializate a new admin user and Access Red Hat Quay interface with credentials (quayadmin/xxx)

```$bash
export QUAY_URL=$(oc get route registry-quay -o jsonpath='{.status.ingress[0].host}')
curl -X POST -k  https://${QUAY_URL}/api/v1/user/initialize --header 'Content-Type: application/json' --data '{ "username": "quayadmin", "password":"quaypass123", "email": "quayadmin@example.com", "access_token": true}' > quay.creds
```

NOTE: The information required to create a valid pull secret in Openshift is saved in an specific file **quay.creds**

### Create a signed image in Red Hat Quay

Once the GPG key has been created and Red Hat Quay is ready, it is time to copy a signed image to the new image registry:

```$bash
export QUAY_URL=$(oc get route registry-quay -o jsonpath='{.status.ingress[0].host}')
export SRC_IMAGE=quay.io/acidonpe/jump-app-front-javascript:latest
export DEST_IMAGE=${QUAY_URL}/quayadmin/jump-app-front-javascript:secure
skopeo copy --sign-by gpguser@email.com docker://${SRC_IMAGE} docker://${DEST_IMAGE} --dest-tls-verify=false --dest-username="quayadmin" --dest-password="quaypass123"
```

### Deploy a GPG sigstore image container

It is required to publish in a different repository, the image that will serve the sigstore for the Openshift nodes. In this case, it is used an Apache server container image but it is possible to use SaaS solutions or other http services.

Please follow the next steps for deploying this sigstore service based on Apache server in Openshift:

```$bash
export REPO_USER="xxxxx"
export REPO_PASS="xxxx"
export REPO_URL="quay.io"
sh 02-deploy-gpg-keystore.sh
```

NOTE: It is required to deploy the sigstore container image in another container images registry because the procedure will define the Red Hat Quay instance deployed as a secure source.

#### Self-signed Certificate Fixes

It is require to add the CA certificate to the laptop in order to push images to a registry with a self-signed certificate

- Obtain de CA certificate

```$bash
openssl s_client -connect ${QUAY_URL}:443 -showcerts
```

- Create *ca.cert* file with the CA information

- Add the CA certificate in the laptop trusted CAs

```$bash
## Linux
??

## MacOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.cert
```

In addition, It is required to create the CA cert in Openshift as well:

```$bash
oc create configmap registry-cas -n openshift-config --from-file=registry-quay-quay.apps.meshtest.sandbox1266.opentlc.com=ca.cert
oc patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"registry-cas"}}}' --type=merge
```

### Configure a GPG sigstore through a Machine Config

Once the previous steps have been completed, it is time to create a *Machine Config* object in order to add the required files in every Openshift installation workers. Please follow the next steps:

```$bash
export QUAY_URL=$(oc get route registry-quay -o jsonpath='{.status.ingress[0].host}')
export SIGSTORE_URL=$(oc get route gpgkeystore -o jsonpath='{.status.ingress[0].host}')
sh 03-create-mc.sh
```

In order to follow the Openshift workers update, it is possible to use the following repository:

```$bash
oc describe mcp worker
oc get nodes
```

## Final Test

If the previous steps have been finished correctly, a signed image solution is deployed in Openshift. The following subsections try to probe the proper functioning of this new solution.

### Success Test

The following procedure tries to deploy an application in Openshift using the previous signed container images pushed in the Red Hat Quay image registry and it should be work well.

Please follow the next procedure that generates the included output:

```$bash
QUAY_URL=$(oc get route registry-quay -o jsonpath='{.status.ingress[0].host}')
export DEST_IMAGE=${QUAY_URL}/quayadmin/jump-app-front-javascript:secure
sh 04-test-signature-ok.sh
....
ok-test-5ff58c6745-c2q4r                      1/1     Running            0               63s
```

NOTE: It is required to make the repository public in Red Hat Quay

### Fail Test

The following procedure tries to deploy an application in Openshift using a non signed container images pushed in the Red Hat Quay image registry and it should be generate an error.

Please follow the next procedure that generates the included output:

```$bash
export QUAY_USER="quayadmin"
export QUAY_PASS="quaypass123"
QUAY_URL=$(oc get route registry-quay -o jsonpath='{.status.ingress[0].host}')
sh 05-test-signature-fail.sh
...
10s          Warning   Failed              pod/fail-test-65c6c476c-dp9vn                Failed to pull image "registry-quay-quay.apps.quaytest.sandbox1832.opentlc.com/quayadmin/httpd-24@sha256:49c64d193ea5ee240fe700642ce509c203126c19d526a8d048cd837554ac7b1c": rpc error: code = Unknown desc = Source image rejected: A signature was required, but no signature exists
```

## Author

Asier Cidon @RedHat