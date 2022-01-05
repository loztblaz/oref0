#!/usr/bin/env bash

die() {
    echo "$@"
    exit 1
}

# TODO: remove the `Acquire::ForceIPv4=true` once Debian's mirrors work reliably over IPv6
echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4

apt-get install -y sudo
sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get install -y git python python-dev software-properties-common python-numpy python-pip watchdog strace tcpdump screen acpid vim locate lm-sensors || die "Couldn't install packages"

# We require jq >= 1.5 for --slurpfile for merging preferences. Debian Jessie ships with 1.4.
if cat /etc/os-release | grep 'PRETTY_NAME="Debian GNU/Linux 8 (jessie)"' &> /dev/null; then
   echo "Please consider upgrading your rig to Jubilinux 0.3.0 (Debian Stretch)!"
   sudo apt-get -y -t jessie-backports install jq || die "Couldn't install jq from jessie-backports"
else
   # Debian Stretch & Buster ship with jq >= 1.5, so install from apt
   sudo apt-get -y install jq || die "Couldn't install jq"
fi

# Install/upgrade to latest version of node (v10) using apt if neither node 8 nor node 10+ LTS are installed
if ! nodejs --version | grep -e 'v8\.' -e 'v1[02468]\.' &> /dev/null ; then
   if getent passwd edison; then
     # Only on the Edison, use nodesource setup script to add nodesource repository to sources.list.d, then install nodejs (npm is a part of the package)
     curl -sL https://deb.nodesource.com/setup_8.x | bash -
     sudo apt-get install -y nodejs=8.* || die "Couldn't install nodejs"
   else
      # From package manager:
      # sudo apt-get install -y nodejs npm || die "Couldn't install nodejs and npm"

      # Raspbian Buster has (at the time of writing) npm 5.8 in the repo, which is not compatible with the repo nodejs version of 10.24
      # An npm self-upgrade (as is attempted below) is successful (bringing npm to major verison 8), but between there and this script trying to `npm install -g json` npm has somehow reverted to the package manager version and become broken (any invocation of npm immediately crashes with a syntax error)
      # At this point, the root cause is unclear and I don't want to deal with it, so I'm deferring to `n`
      # `n` instead of `nvm` to avoid issues with nvm not being available to all users (see https://stackoverflow.com/questions/21215059/cant-use-nvm-from-root-or-sudo)
      echo "Installing node via n..."
      curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o n
      # Install the latest version of node 10.x.x
      bash n 10
      # Delete the local n binary used to boostrap the install
      rm n
      # Install n globally
      sudo npm install -g n
   fi
   
   # Upgrade to the latest supported version of npm for the current node version
   sudo npm upgrade -g npm|| die "Couldn't update npm"

   ## You may also need development tools to build native addons:
   ## sudo apt-get install gcc g++ make
fi

# upgrade setuptools to avoid "'install_requires' must be a string" error
sudo pip install setuptools -U # no need to die if this fails
sudo pip install -U --default-timeout=1000 git+https://github.com/openaps/openaps.git || die "Couldn't install openaps toolkit"
sudo pip install -U openaps-contrib || die "Couldn't install openaps-contrib"
sudo openaps-install-udev-rules || die "Couldn't run openaps-install-udev-rules"
sudo activate-global-python-argcomplete || die "Couldn't run activate-global-python-argcomplete"
sudo npm install -g json || die "Couldn't install npm json"
echo openaps installed
openaps --version
