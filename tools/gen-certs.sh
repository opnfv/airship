#!/bin/bash

# Assumption:
# Your site definition exists in github.com/opnfv/site folder without certificates
# If you run on site that already has certificates, existing ones will be replaced.

# Usage:
# Run gen_cert.sh <site-name>
# Example: gen_cert.sh intel-pod10.
# Certificates will be copied to /tmp/certificates/airship/site/<site_name>/secrets/certificates/ folder.
# Push the changes back from /tmp/certificates/airship folder
# by running git commit and git review.

set -x

export GERRIT_REFSPEC=${GERRIT_REFSPEC:-master}
export SITE_DEF=${SITE_DEF:-airship/site/$1/site-definition.yaml}
export SITE_NAME=$1
export TERM_OPTS=${TERM_OPTS:-" "}

TMP_DIR=/tmp/certificates
mkdir $TMP_DIR
cd $TMP_DIR

## Deps

pkg_check() {
  for pkg in $@; do
    sudo dpkg -s $pkg &> /dev/null || sudo apt -y install $pkg
  done
}

help() {
  echo "Usage: gen-certs.sh <site_name>"
}


## Repos
read_yaml() {
  python3 -c "import yaml;print(yaml.load(open('$1'))$2)"
}

git_checkout() {
  git clone $1
  cd ${1##*/}

  # check refs for patchsets
  if [[ $2 == *"refs"* ]]; then
    git fetch origin $2
    git checkout FETCH_HEAD
  else
    git checkout $2
  fi

  git log -1
  cd $TMP_DIR
}

clone_repos() {
  # clone/checkout site manifests
  git_checkout 'https://gerrit.opnfv.org/gerrit/airship' $GERRIT_REFSPEC
  
  # Create a branch so that you can push the changes.
  cd airship
  git checkout -b certgen
  cd $TMP_DIR
  
  # clone treasuremap (only required for tools/airship)
  # match treasuremap to global from site-definition
  SITE_DEF_KEY="['data']['repositories']['global']['revision']"
  TREASUREMAP_REF=$(read_yaml $SITE_DEF "$SITE_DEF_KEY")

  git_checkout 'https://review.opendev.org/airship/treasuremap' $TREASUREMAP_REF
}

## Cleanup
## Delete certificates.yaml from site/<site_name>/secrets/ folder
cert_cleanup() {
  rm airship/site/$1/secrets/certificates/certificates.yaml
}

## Deployment

pegleg_collect() {
  sudo -E treasuremap/tools/airship pegleg site \
    -r /target/airship collect -s collect $SITE_NAME
}

gen_certs() {
  mkdir certs
  sudo -E treasuremap/tools/airship promenade generate-certs \
    -o /target/certs /target/collect/*.yaml
}

copy_certs() {
  cp certs/certificates.yaml airship/site/$1/secrets/certificates/
}

if [ $# -eq 0 ]
  then
    help
    exit 1
fi

#Check if necessary packages exists
pkg_check docker.io git ipmitool python3-yaml
#clone required repositories
clone_repos
#cleanup any existing certificates.yaml
cert_cleanup
pegleg_collect
gen_certs
copy_certs
