#!/bin/bash

set -x

export OS_AUTH_URL=${OS_AUTH_URL:-http://iam-airship.intel-pod17.opnfv.org:80/v3}
export OS_USERNAME=${OS_USERNAME:-shipyard}
export OS_PASSWORD=${OS_PASSWORD:-password123}

export IPMI_USER=${IPMI_USER:-root}
export IPMI_PASS=${IPMI_PASS:-root}

export GEN_SSH=${GEN_SSH:-intel-pod17-genesis}
export SITE_NAME=${SITE_NAME:-intel-pod17}

export GEN_IPMI=${GEN_IPMI:-10.10.170.11}
export NODES_IPMI=${NODES_IPMI:-'10.10.170.12 10.10.170.13 10.10.170.14 10.10.170.15'}

export GERRIT_REFSPEC=${GERRIT_REFSPEC:-master}
export SITE_DEF=${SITE_DEF:-airship/site/intel-pod17/site-definition.yaml}

TMP_DIR=$(mktemp -d)
cd $TMP_DIR

trap "{ sudo rm -rf $TMP_DIR; }" EXIT


## Deps

pkg_check() {
  for pkg in $@; do
    sudo dpkg -s $pkg &> /dev/null || sudo apt -y install $pkg
  done
}
pkg_check docker.io git ipmitool python3-yaml

help() {
  echo "Usage: deploy.sh <deploy_site|update_site>"
}


## Cleanup

genesis_cleanup() {

  ssh $GEN_SSH sudo systemctl disable kubelet
  ssh $GEN_SSH sudo systemctl disable docker
  ssh $GEN_SSH sudo touch /forcefsck

  # reset bare-metal servers

  ALL_NODES="${GEN_IPMI} ${NODES_IPMI}"
  for node in $ALL_NODES; do
    ipmitool -I lanplus -H $node -U $IPMI_USER -P $IPMI_PASS chassis power off
  done

  ipmitool -I lanplus -H $GEN_IPMI -U $IPMI_USER -P $IPMI_PASS chassis power on

  while ! ssh $GEN_SSH hostname; do :; done

  # cleanup previous k8s/airship install

  ssh $GEN_SSH rm -rf promenade genesis.sh
  ssh $GEN_SSH git clone https://review.opendev.org/airship/promenade
  ssh $GEN_SSH sudo promenade/tools/cleanup.sh -f > /dev/null

  ssh $GEN_SSH sudo parted -s /dev/sdb mklabel gpt
  ssh $GEN_SSH sudo rm -rf /var/lib/ceph
  ssh $GEN_SSH sudo rm -rf /var/lib/docker
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

  # clone treasuremap (only required for tools/airship)
  # match treasuremap to global from site-definition
  SITE_DEF_KEY="['data']['repositories']['global']['revision']"
  TREASUREMAP_REF=$(read_yaml $SITE_DEF "$SITE_DEF_KEY")

  git_checkout 'https://review.opendev.org/airship/treasuremap' $TREASUREMAP_REF
}


## Deployment

pegleg_collect() {
  sudo -E treasuremap/tools/airship pegleg site \
    -r /target/airship collect -s collect $SITE_NAME
}

promenade_bundle() {
  mkdir bundle
  sudo -E treasuremap/tools/airship promenade build-all \
    --validators -o /target/bundle /target/collect/*.yaml
}

genesis_deploy() {
  scp bundle/genesis.sh $GEN_SSH:
  ssh $GEN_SSH 'sudo ./genesis.sh' && sleep 120
}

site_action() {

  # Site deployment with Shipyard, see more details here
  # https://airship-treasuremap.readthedocs.io/en/latest/authoring_and_deployment.html#deploy-site-with-shipyard

  sudo -E treasuremap/tools/airship shipyard create configdocs \
    $SITE_NAME --directory=/target/collect --replace
  sudo -E treasuremap/tools/airship shipyard commit configdocs

  sudo -E treasuremap/tools/airship shipyard create action \
    --allow-intermediate-commits $1

  sudo -E treasuremap/tools/gate/wait-for-shipyard.sh
}

create_public_network() {
  export OS_AUTH_URL=${OS_AUTH_URL:-http://identity-airship.intel-pod17.opnfv.org:80/v3}
  sudo -E treasuremap/tools/openstack stack create --wait \
    -t /target/airship/tools/files/heat-public-net-deployment.yaml \
    public-network
}

case "$1" in
'deploy_site')
  genesis_cleanup
  clone_repos
  pegleg_collect
  promenade_bundle
  genesis_deploy
  site_action $1
  create_public_network
  ;;
'update_site')
  clone_repos
  pegleg_collect
  site_action $1
  ;;
*) help
   exit 1
  ;;
esac

