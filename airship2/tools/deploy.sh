source ${HOME}/.airship/airship.env

INIT_SITE=${INIT_SITE:-true}

cd ${AIRSHIP_CONFIG_MANIFEST_DIRECTORY}/airshipctl
./tools/deployment/10_install_essentials.sh
# Recommend to add the user to the docker group
sudo usermod -aG docker $USER
./tools/deployment/21_systemwide_executable.sh
if [ "$INIT_SITE" = true ] ; then
  ./tools/init_site.sh
fi

