#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -ne 0 ]] && exit_on_error "Must run as root"

##
## Register the system and enable baseos and appstream repos
##

subscription-manager register \
    --username "$RHSM_USER" --password "$RHSM_PASS" \
    || exit_on_error "Unable to register subscription"

if [[ "$POOL" = "" ]]
then
    POOL=$(subscription-manager list --all --available | \
        grep 'Pool ID\|Entitlement Type\|Subscription Name\|Available' | \
        grep -A3 'Employee SKU' | grep -B3 $TYPE | grep 'Pool ID' | \
        awk '{print $NF; exit}')

    if [[ "$POOL" = "" ]]
    then
        echo "No matching pools found"
        exit 1
    fi
fi

subscription-manager attach --pool="$POOL" || exit 1
subscription-manager repos --disable='*'
subscription-manager repos \
    --enable=rhel-9-for-x86_64-baseos-rpms \
    --enable=rhel-9-for-x86_64-appstream-rpms

##
## Update the system
##

dnf -y update
dnf -y clean all

