#!/bin/bash

# This is an scripts managing lxd container
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

local user_id=$(id -u)
case "$2" in
    $CONTAINER_DISTRO_SUSE)
        # Creating group whell and add sudoers rules
        lxc exec ${1} -- sh -c "echo \"%wheel ALL=(ALL:ALL) ALL\" > /etc/sudoers.d/wheel"
        lxc exec ${1} -- sed -i 's/Defaults targetpw   # ask for the password of the target user i.e. root/#Defaults targetpw/g' /etc/sudoers
        lxc exec ${1} -- sed -i 's/ALL   ALL=(ALL) ALL   # WARNING! Only use this together with^*/#ALL   ALL=(ALL) ALL/g' /etc/sudoers
        lxc exec ${1} -- groupadd wheel
        # Create user devel
        lxc exec ${1} -- sh -c "[ ! -f /etc/nsswitch.conf ] && [ -f /usr/etc/nsswitch.conf ] && ln -s /usr/etc/nsswitch.conf /etc/nsswitch.conf"
        lxc exec ${1} -- useradd devel --home /home/devel --create-home --uid $user_id --groups wheel --gid wheel
        lxc exec ${1} -- usermod -aG wheel devel
        lxc exec ${1} -- sh -c "echo -e \"devel\ndevel\" | passwd devel"
        ;;
    $CONTAINER_DISTRO_DEBIAN | $CONTAINER_DISTRO_UBUNTU)
        lxc exec ${1} -- adduser devel --home /home/devel --uid 1000 --ingroup sudo --disabled-password --gecos ""
        lxc exec ${1} -- sh -c 'echo "devel\ndevel" | passwd devel'
        ;;
    $CONTAINER_DISTRO_CENTOS | $CONTAINER_DISTRO_FEDORA)
        lxc exec ${1} -- useradd devel --home /home/devel --create-home --uid $user_id --groups wheel --gid wheel
        lxc exec ${1} -- sh -c "echo -e \"devel\ndevel\" | passwd devel"
        ;;
    *)
        echo_error "Unknown distro to start ssh services"
        ;;
esac