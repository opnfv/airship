#!/bin/bash

set -x

export OS_USERNAME=${OS_USERNAME:-shipyard}
export OS_PASSWORD=${OS_PASSWORD:-password123}

export IPMI_USER=${IPMI_USER:-root}
export IPMI_PASS=${IPMI_PASS:-root}

export GERRIT_REFSPEC=${GERRIT_REFSPEC:-master}

export TERM_OPTS=${TERM_OPTS:-" "}

## Source Environment Variables.

help() {
  echo "Usage: deploy.sh <site_name> <deploy_site|update_site>"
}

if [[ $# -ne 2 ]]
  then
    help
    exit 1
fi

source $(dirname "$(realpath $0)")/../site/$1/$1.env

if [ -z "$AS_HOME" ]; then
  WORK_DIR=$(mktemp -d)
  trap "{ sudo rm -rf $WORK_DIR; }" EXIT
else
  WORK_DIR=$AS_HOME
fi

cd ${WORK_DIR}

## Deps

pkg_check() {
  for pkg in $@; do
    sudo dpkg -s $pkg &> /dev/null || sudo apt -y install $pkg
  done
}
pkg_check docker.io git ipmitool python3-yaml



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

  sleep 11 # wait for genesis node to power-off
  ipmitool -I lanplus -H $GEN_IPMI -U $IPMI_USER -P $IPMI_PASS chassis power on

  while ! ssh $GEN_SSH hostname; do :; done

  # cleanup previous k8s/airship install

  ssh $GEN_SSH rm -rf promenade genesis.sh
  ssh $GEN_SSH git clone https://review.opendev.org/airship/promenade
  ssh $GEN_SSH sudo promenade/tools/cleanup.sh -f > /dev/null

  ssh $GEN_SSH sudo parted -s /dev/sdb mklabel gpt
  ssh $GEN_SSH sudo rm -rf /var/lib/ceph
  ssh $GEN_SSH sudo rm -rf /var/lib/docker

  ssh $GEN_SSH sudo /etc/init.d/docker restart
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
  cd $WORK_DIR
}

clone_repos() {
  if [ -d "airship" ]; then
    echo "Found existing airship folder. Skip repo clone."
  else
    # clone/checkout site manifests
    git_checkout 'https://gerrit.opnfv.org/gerrit/airship' $GERRIT_REFSPEC
  fi

  if [ -d "treasuremap" ]; then
    echo "Found existing treasuremap folder in the working directory. Skip repo clone."
  else
    # clone treasuremap (only required for tools/airship)
    # match treasuremap to global from site-definition
    SITE_DEF_KEY="['data']['repositories']['global']['revision']"
    TREASUREMAP_REF=$(read_yaml $SITE_DEF "$SITE_DEF_KEY")
    echo "TREASUREMAP_REF $TREASUREMAP_REF"
    git_checkout 'https://review.opendev.org/airship/treasuremap' $TREASUREMAP_REF
    git fetch https://review.opendev.org/airship/treasuremap refs/changes/33/707733/4 && git cherry-pick FETCH_HEAD
  fi
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
  export OS_AUTH_URL=${OS_AUTH_URL_IDENTITY}
  sudo -E treasuremap/tools/openstack stack create --wait \
    -t /target/airship/tools/files/heat-public-net-deployment-$SITE_NAME.yaml \
    public-network
}

case "$2" in
'deploy_site')
  genesis_cleanup
  clone_repos
  pegleg_collect
  promenade_bundle
  genesis_deploy
  site_action $2
  create_public_network
  ;;
'update_site')
  clone_repos
  pegleg_collect
  site_action $2
  ;;
*) help
   exit 1
  ;;
esac

