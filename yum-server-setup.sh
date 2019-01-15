#!/bin/env bash

function print_seperator {
echo -e "------------------------------------"
}

function print_header {
print_seperator
echo -e "$1"
print_seperator
}

function print_item {
echo -e "** $1"
}

function print_cmd {
echo -e "$ $1"
eval "$1"
}

function get_deprecated {
   curl -s http://mirror.centos.org/centos/${releasever}/readme | awk '/deprecated/ {print 1}'
   ret=$?
   [[ $ret -gt 0 ]] && exit $ret
}

function get_repos {
   awk '/name/ {print $NF}' /etc/yum.repos.d/*
   ret=$?
   [[ $ret -gt 0 ]] && exit $ret
}

function make_version { 
   value="${VERSION_MAJOR}"
   [[ -n "${VERSION_MINOR}" ]] && value="${value}.${VERSION_MINOR}"
   [[ -n "${VERSION_MONTH}" ]] && value="${value}.${VERSION_MONTH}"
   echo "$value" 
}

do_install=false
if [[ "$do_install" == "true" ]]; then
   print_header "Installing Dependencies"
   print_cmd "yum install epel-release"
   print_cmd "yum install nginx createrepo yum-utils"
fi

# Only applies to versions after CentOS 7
# TODO: test this with CentOS 7 repos
VERSION_MAJOR=7
VERSION_MINOR=0
VERSION_MONTH=1406

releasever=$(make_version)
basearch=x86_64

YUM_REPO_ROOT=/srv/repos
CENTOS_MIRROR="http://mirror.centos.org/centos/${releasever}"
CENTOS_VAULT="http://vault.centos.org/${releasever}"

repofile="${HOME}/centos-${releasever}.repo"

[[ $(get_deprecated) -gt 0 ]] && mirror=${CENTOS_VAULT} || mirror=${CENTOS_MIRROR}

print_seperator
print_item "Found ${releasever} on ${mirror}"
print_seperator
print_item "Using ${YUM_REPO_ROOT} as mirror root."
print_seperator

cat <<EOF > ${repofile}
[base]
name=CentOS-${releasever} - Base
baseurl=${mirror}/os/${basearch}/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-${VERSION_MAJOR}
priority=1

#released updates
[updates]
name=CentOS-${releasever} - Updates
baseurl=${mirror}/${releasever}/updates/${basearch}/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-${VERSION_MAJOR}
priority=1

#additional packages that may be useful
[extras]
name=CentOS-${releasever} - Extras
baseurl=${mirror}/${releasever}/extras/${basearch}/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-${VERSION_MAJOR}
priority=1
EOF


