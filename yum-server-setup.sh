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

do_install=false
if [[ "$do_install" == "true" ]]; then
	print_header "Installing Dependencies"
	print_cmd "yum install epel-release"
	print_cmd "yum install nginx createrepo yum-utils"
fi

usage() {
script_name=$(basename $0)
cat << EOF

usage: ${script_name} [-g] version [repos...]

-h, --help	
	print this message and exit
-g, --generate	
	print a repofile for this version to stdout and exit

reposync options
-c, --config <c_arg>	
	use c_arg as yum config file

-u, --urls	don't sync repositories, just print the urls

-n, --newest	only download latest release of rpms

EOF
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
key="$1"

case $key in
	-g|--generate)
	CENTOS_MIRROR="http://mirror.centos.org/centos/${releasever}"
	CENTOS_VAULT="http://vault.centos.org/${releasever}"
	opt_release=${2?"Error: generate requires a release string"}
	opt_arch=${3-x86_64}
	if isdeprecated ${releasever}
		then mirror=${CENTOS_VAULT}
		else mirror=${CENTOS_MIRROR}
	fi
	generate_centos_repofile ${mirror} ${opt_release} ${opt_arch}
	exit
	;;
	-c|--config)
	opt_configfile=$2
	shift
	shift
	;;
	-o|--output-directory)
	opt_outdir=$2
	shift
	shift
	;;
	-n|--newest)
	opt_newest=1
	shift
	;;
	-x|--no-gpgcheck)
	opt_nogpgcheck=1
	shift
	;;
	-h|-?|--help) 
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
echo $@

#output=${YUM_REPO_ROOT}/centos/${releasever}/os/${basearch}/
for repo in "$@"; do
	reposync ${opt_configfile+-c ${opt_configfile}} -r $repo \
		${opt_outdir--u} \
		${opt_outdir+${opt_newest+-n} ${opt_nogpgcheck--g} --download-metadata --downloadcomps --norepopath --download_path=${opt_outdir}}
done
