#!/bin/bash
##
# Create a MC to use only signed images
##

cat > /tmp/policy.json <<EOF
{
  "default": [
    {
      "type": "insecureAcceptAnything"
    }
  ],
  "transports": {
    "docker": {
      "${QUAY_URL}": [
        {
          "type": "signedBy",
          "keyType": "GPGKeys",
          "keyPath": "/etc/pki/gpgkey.pub"
        }
      ]
    },
    "docker-daemon": {
      "": [
        {
          "type": "insecureAcceptAnything"
        }
      ]
    }
  }
}
EOF

cat <<EOF > /tmp/${QUAY_URL}.yaml
docker:
     ${QUAY_URL}:
         sigstore: http://${SIGSTORE_URL}/sigstore
EOF


# GPG_PUB_KEY=$(cat gpgkey.pub | base64 -w0 )
# POLICY_CONFIG=$( cat policy.json | base64 -w0 )
# CUSTOM_REG=$( cat registry.redhat.io.yaml | base64 -w0 )

GPG_PUB_KEY=$(cat gpgkey.pub | base64 )
POLICY_CONFIG=$( cat /tmp/policy.json | base64 )
CUSTOM_REG=$( cat /tmp/${QUAY_URL}.yaml | base64 )

cat > /tmp/51-worker-rh-registry-trust.yaml <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 51-worker-custom-registry-trust
spec:
  config:
    ignition:
      config: {}
      security:
        tls: {}
      timeouts: {}
      version: 2.2.0
    networkd: {}
    passwd: {}
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,${POLICY_CONFIG}
          verification: {}
        filesystem: root
        mode: 420
        path: /etc/containers/policy.json
      - contents:
          source: data:text/plain;charset=utf-8;base64,${CUSTOM_REG}
          verification: {}
        filesystem: root
        mode: 420
        path: /etc/containers/registries.d/${QUAY_URL}.yaml
      - contents:
          source: data:text/plain;charset=utf-8;base64,${GPG_PUB_KEY}
          verification: {}
        filesystem: root
        mode: 420
        path: /etc/pki/gpgkey.pub
  osImageURL: ""
EOF

oc apply -f /tmp/51-worker-rh-registry-trust.yaml