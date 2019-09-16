#!/bin/bash

HOSTNAME=$1

echo "Do you wish to destroy + undefine + remove $1?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done

virsh destroy $HOSTNAME
virsh undefine $HOSTNAME
lvremove -y /dev/vg0/$HOSTNAME
