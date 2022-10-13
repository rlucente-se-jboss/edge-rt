#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -eq 0 ]] && exit_on_error "Must not run as root"

##
## Add the new source repo for image builder
##

composer-cli sources add rt_source.toml

composer-cli sources list
composer-cli sources info rt

