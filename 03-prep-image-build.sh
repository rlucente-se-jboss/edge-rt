#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -eq 0 ]] && exit_on_error "Do not run as root"

##
## Generate ssh keys for edge user
##

ssh-keygen -f $HOME/.ssh/id_$EDGE_USER -t rsa -P "" \
           -C $EDGE_USER@localhost.localdomain
cp $HOME/.ssh/id_$EDGE_USER.pub .

##
## Create the blueprint file for an edge device
##

cat > edge-blueprint.toml <<EOF
name = "Edge-RT"
description = ""
version = "0.0.1"

[[groups]]
name = "RT"

[customizations.kernel]
name = "kernel-rt"
append = ""

[[customizations.user]]
name = "$EDGE_USER"
description = "default edge user"
password = "$(openssl passwd -6 $EDGE_PASS)"
key = "$(cat id_$EDGE_USER.pub)"
home = "/home/$EDGE_USER/"
shell = "/usr/bin/bash"
groups = [ "wheel" ]

[[customizations.sshkey]]
user = "$EDGE_USER"
key = "$(cat id_$EDGE_USER.pub)"
EOF

