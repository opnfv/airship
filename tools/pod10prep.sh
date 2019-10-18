#!/bin/bash

set -x

sed -i 's/ens785f1/eno4/g' ../type/cntt/software/charts/osh/openstack-compute-kit/neutron.yaml

cp files/heat-public-net-deployment-pod10.yaml  files/heat-public-net-deployment.yaml
