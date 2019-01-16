#!/bin/env bash

generate_centos_repofile() {
	local mirror=$1
	local releasever=$2
	local basearch=$3

	cat <<EOF
[main]
reposdir=/dev/null

[os]
name=CentOS-${releasever} - Base
baseurl=${mirror}/os/${basearch}/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-${releasever/.[0-9]*}
priority=1

#released updates
[updates]
name=CentOS-${releasever} - Updates
baseurl=${mirror}/${releasever}/updates/${basearch}/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-${releasever/.[0-9]*}
priority=1

#additional packages that may be useful
[extras]
name=CentOS-${releasever} - Extras
baseurl=${mirror}/${releasever}/extras/${basearch}/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-${releasever/.[0-9]*}
priority=1
EOF
}

isdeprecated() {
   local releasever=$1
   local url=http://mirror.centos.org/centos/${releasever}/readme 
   if [[ $(curl --silent --fail $url | awk '/deprecated/ { print 1 }') == "1" ]]; then
	true
   else false; fi
}

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

function get_repos {
   awk '/name/ {print $NF}' /etc/yum.repos.d/*
   ret=$?
   [[ $ret -gt 0 ]] && exit $ret
}

do_install=false
if [[ "$do_install" == "true" ]]; then
	print_header "Installing Dependencies"
	print_cmd "yum install epel-release"
	print_cmd "yum install nginx createrepo yum-utils"
fi

usage() {
script_name=$(basename $0)
cat << EOF
${script_name} [-g] version [repos...]
-x, --arch	override default (x86-64) arch string

-g, --generate	print a repofile for this version to stdout and exit

reposync options
-c, --config <c_arg>	use c_arg as yum config file

-u, --urls	don't sync repositories, just print the urls

-n, --newest	only download latest release of rpms

-h, --help	print this message and exit


EOF
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
key="$1"

case $key in
	-g|--generate)
	opt_genrepofile=1
	shift
	;;
	-x|--arch)
	opt_arch="$2"
	shift
	shift
	;;
	-c|--config)
	opt_configfile=$2
	shift
	shift
	;;
	-u|--urls)
	opt_printurls=1
	shift
	;;
	-n|--newest)
	opt_newest=1
	shift
	;;
	-g|--no-gpgcheck)
	opt_nogpgcheck=1
	shift
	;;
	-h|--help) 
	usage
	exit
	;;
	*)
	POSITIONAL+=("$1")
	shift
	;;
esac
done
set -- "${POSITIONAL[@]}"

YUM_REPO_ROOT=/srv/repos
CENTOS_MIRROR="http://mirror.centos.org/centos/${releasever}"
CENTOS_VAULT="http://vault.centos.org/${releasever}"

releasever=$1
if [[ -z ${releasever} ]]; then usage; exit 1; fi
shift

basearch=${opt_arch:-x86_64}

if [[ $opt_genrepofile ]]; then
	if isdeprecated ${releasever}
		then mirror=${CENTOS_VAULT}
		else mirror=${CENTOS_MIRROR}
	fi
	generate_centos_repofile ${mirror} ${releasever} ${basearch}
	exit 0
fi

output=${YUM_REPO_ROOT}/centos/${releasever}/os/${basearch}/
repo=extras

reposync ${opt_configfile+-c $opt_configfile} ${opt_newest+-n} ${opt_printurls+-u} -r $repo ${opt_nogpgcheck--g} --download_path=/srv/repos/
#reposync ${opt_configfile+-c $opt_configfile} ${opt_newest+-n} ${opt_printurls+-u} -r $repo -g

