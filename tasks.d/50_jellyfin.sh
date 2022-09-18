#!/bin/bash

# This is a script for managing lxd container
#
# Copyright 2022 Valentin LEFEBVRE
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

case "$2" in
    $CONTAINER_DISTRO_SUSE)
        echo_warning "not implemented for opensuse distro"
        exit 0
        ;;
    $CONTAINER_DISTRO_DEBIAN | $CONTAINER_DISTRO_UBUNTU)
        # Install jellyfin from repository
        lxc exec ${1} -- extrepo enable jellyfin
        lxc exec ${1} --  sh -c 'apt update'
        lxc exec ${1} --  sh -c 'apt install -y jellyfin'
        lxc exec ${1} -- systemctl restart jellyfin
        lxc exec ${1} -- systemctl enable jellyfin
        ;;
    $CONTAINER_DISTRO_CENTOS | $CONTAINER_DISTRO_FEDORA)
        echo_warning "not implemented for redhat based distro"
        ;;
    *)
        echo_error "Unknown distro to install packages"
        exit 0
        ;;
esac

local ip_addr=$(get_container_ip ${1})
echo_info "Jellyfin well installed on $1, go to http://$ip_addr:8096"