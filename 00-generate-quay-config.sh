
#!/bin/bash
##
# Create Quay Configurations
##

cat <<EOF > /tmp/config.yaml
FEATURE_USER_INITIALIZE: true
BROWSER_API_CALLS_XHR_ONLY: false
SUPER_USERS:
- quayadmin
FEATURE_USER_CREATION: false
DISTRIBUTED_STORAGE_CONFIG:
  s3Storage:
    - S3Storage
    - host: ${AWS_S3_API}
      s3_access_key: ${AWS_ACCESS_KEY_ID}
      s3_secret_key: ${AWS_SECRET_ACCESS_KEY}
      s3_bucket: ${AWS_S3_BUCKET}
      storage_path: /datastorage/registry
DISTRIBUTED_STORAGE_DEFAULT_LOCATIONS: []
DISTRIBUTED_STORAGE_PREFERENCE:
    - s3Storage
ALLOW_PULLS_WITHOUT_STRICT_LOGGING: false
AUTHENTICATION_TYPE: Database
DEFAULT_TAG_EXPIRATION: 2w
ENTERPRISE_LOGO_URL: /static/img/quay-horizontal-color.svg
FEATURE_BUILD_SUPPORT: false
FEATURE_DIRECT_LOGIN: true
FEATURE_MAILING: false
REGISTRY_TITLE: Quay
REGISTRY_TITLE_SHORT: Quay
SETUP_COMPLETE: true
TAG_EXPIRATION_OPTIONS:
- 2w
TEAM_RESYNC_STALE_TIME: 60m
TESTING: false
EOF

oc create secret generic --from-file config.yaml=/tmp/config.yaml init-config-bundle-secret