#!/bin/bash

set -x

log ()  {
    printf "$(date)\t%s\n" "${1}"
}

TO_RM=(
    "/etc/cni"
    "/etc/coredns"
    "/etc/etcd"
    "/etc/genesis"
    "/etc/kubernetes"
    "/etc/promenade"
    "/etc/systemd/system/kubelet.service"
    "/home/ceph"
    "/tmp/tmp.*"
    "/var/lib/etcd"
    "/var/lib/kubelet"
    "/var/lib/openstack-helm"
    "/var/log/containers"
    "/var/log/pods"
    "/var/log/armada"
    "/etc/modprobe.d/krbd_blacklist.conf"
    "/srv/elasticsearch-data"
    "/srv/elasticsearch-master"
    "/srv/prometheus-data"
)

prune_docker() {
    log "Docker prune"
    docker volume prune -f
    docker system prune -a -f
}

remove_containers() {
    log "Remove all Docker containers"
    docker ps -aq 2> /dev/null | xargs --no-run-if-empty docker rm -fv
    log "Remove all containerd pods"
    systemctl restart containerd || true
    sleep 60
    crictl rmp -a -f || true
    log "Remove any remaining containerd containers"
    crictl rm -a -f || true
    systemctl stop containerd || true
}

remove_files() {
    for item in "${TO_RM[@]}"; do
        log "Removing ${item}"
        rm -rf "${item}"
    done
}

reset_docker() {
    log "Remove all local Docker images"
    docker images -qa | xargs --no-run-if-empty docker rmi -f
    log "Remove remaining Docker files"
    systemctl stop docker
    if ! rm -rf /var/lib/docker/*; then
        log "Failed to cleanup some files in /var/lib/docker"
        find /var/lib/docker
    fi
    log "Remove all local containerd data"
    if ! rm -rf /var/lib/containerd/*; then
        log "Failed to cleanup some files in /var/lib/containerd/"
        find /var/lib/containerd
    fi
}

stop_kubelet() {
    log "Stop Kubelet and clean pods"
    systemctl stop kubelet || true
    # Issue with orhan PODS
    # https://github.com/kubernetes/kubernetes/issues/38498
    find /var/lib/kubelet/pods 2> /dev/null | while read orphan_pod; do
        if [[ ${orphan_pod} == *io~secret/* ]] || [[ ${orphan_pod} == *empty-dir/* ]]; then
            umount "${orphan_pod}" || true
            rm -rf "${orphan_pod}"
        fi
    done
}

wipe_disk() {
    CEPH_VG=$(vgs | tail -n +1 | awk '{print $1}' | grep ceph-vg- | paste -d " "  - -)

    if [[ x$CEPH_VG != 'x' ]]; then
        vgremove -f $CEPH_VG
    fi

    log "Wipe out CEPH disks"
    apt install --yes gdisk
    echo "====Earsing disk sdb===="
    sudo sgdisk -Z /dev/sdb
    sudo dd if=/dev/zero of=/dev/sdb bs=1M count=200
}

service_exists() {
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}

FORCE=0
RESET_DOCKER=0
while getopts "fk" opt; do
    case "${opt}" in
        f)
            FORCE=1
            ;;
        k)
            RESET_DOCKER=1
            ;;
        *)
            echo "Unknown option"
            exit 1
            ;;
    esac
done

if [[ $FORCE == "0" ]]; then
    echo Warning:  This cleanup script is very aggresive.  Run with -f to avoid this prompt.
    while true; do
        read -p "Are you sure you wish to proceed with aggressive cleanup?" yn
        case $yn in
            [Yy]*)
                RESET_DOCKER=1
                break
                ;;
            *)
                echo Exitting.
                exit 1
        esac
    done
fi

if service_exists kubelet; then
    stop_kubelet
    remove_containers
    remove_files
    prune_docker
    systemctl daemon-reload
    systemctl start containerd.service
    if [[ $RESET_DOCKER == "1" ]]; then
        echo "hi"
        reset_docker
    fi
    systemctl start containerd
#sudo crictl pull docker.io/busybox:1.28.3
#sudo crictl pull docker.io/haproxy:1.8.19
    service docker restart
fi
wipe_disk

