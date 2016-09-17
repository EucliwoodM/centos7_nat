#!/usr/bin/env bash

declare -A input
declare -A backup_iptables
declare -A backup_ipvsm
declare -A yc

input[ACTION]=$1
input[FLAG]=$2
input[PATH]=$3
input[ARG_NUM]=$#
input[ARGS]=$@

backup[DATE]=$(date +%d%m%y-%H%M%S)
# Backup iptables vars.
backup_iptables[BACKUP_FILE]="/backup_${backup[DATE]}.save"
backup_iptables[FILE]="/active.save"
backup_iptables[TEMP_PATH]="/tmp/iptables_backup"

# Backup iptables vars.
backup_ipvsm[BACKUP_FILE]="/backup_${backup[DATE]}.save"
backup_ipvsm[FILE]="/active.save"
backup_ipvsm[TEMP_PATH]="/tmp/ipvsm_backup"

# Import yColor
yColor_tools="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
source ${yColor_tools}"/yColor-tools/test_yColor.sh"

# Check if script is run by root.
function checkRoot {
	if [ "$EUID" -ne 0 ]; then
		printf "%sYou need to run as %sroot. %s\n"\
			"${yc[RE]}"\
			"${yc[RE_B]}"\
			"${yc[RESET]}"
		return 1
	else
		printf "%sYou run as %sroot. %s\n"\
			"${yc[GR]}"\
			"${yc[GR_B]}"\
			"${yc[RESET]}"
		return 0
	fi
}

# Create backup dir.
function createDir {

	temp_path=$1
	mkdir -p ${temp_path}
	if [ $? -eq 0 ]; then
		printf "%sCreated backup dir: \n%s%s%s\n"\
			"${yc[GR]}"\
			"${yc[GR_U]}"\
			"	${temp_path}"\
			"${yc[RESET]}"
		return 0
	else
		printf "%sFailed during: \n%smkdir %s%s%s\n"\
			"${yc[RE]}"\
			"${yc[RE_B]}"\
			"${yc[RE_U]}"\
			"	${temp_path}"\
			"${yc[RESET]}"
		return 1
	fi
}

# Save rules to file
function saveFile {

	temp_path=$1
	full_path=$1$2
	rules=$3

	printf "%sSaving %s%s\n"\
		 "${yc[B]}"\
		 "${rules}"\
		 "${yc[RESET]}"

	if [ -d "${temp_path}" ]; then

		# Check witch rules to back up.
		if [ "${rules}" == "iptables" ]; then
			# Backup iptabels
			iptables-save > ${full_path}
		elif [ "${rules}" == "ipvsm" ]; then
			# Backup ipvsadm
			ipvsadm-save > ${full_path}
		fi

		printf "%sCreated file: \n%s%s%s\n"\
			"${yc[GR]}"\
			"${yc[GR_U]}"\
			"	${full_path}"\
			"${yc[RESET]}"
		return 0
	else
		printf "%sFailed to find path: \n%s%s%s\n"\
			"${yc[RE]}"\
			"${yc[RE_U]}"\
			"	${temp_path}"\
			"${yc[RESET]}"

		printf "%sFailed create file: \n%s%s%s\n"\
			"${yc[RE]}"\
			"${yc[RE_U]}"\
			"	${full_path}"\
			"${yc[RESET]}"
		return 1
	fi
}

function save {

	# Just to change file name
	if [ "$1" == "backup" ]; then
		ip_file=${backup_iptables[BACKUP_FILE]}
		vs_file=${backup_ipvsm[BACKUP_FILE]}
	else
		ip_file=${backup_iptables[FILE]}
		vs_file=${backup_ipvsm[FILE]}
	fi
	ip_path=${backup_iptables[TEMP_PATH]}
	vs_path=${backup_ipvsm[TEMP_PATH]}

	# Trying to save iptables rules
	saveFile ${ip_path} ${ip_file} "iptables"
	if [ $? -ne 0 ]; then
		createDir ${ip_path}
		if [ $? -ne 0 ];then
			exit 1
		else	# Trying to save agin
			saveFile ${ip_path} ${ip_file} "iptables"
		fi
	fi

	# Trying to save ipvsm rules
	saveFile ${vs_path} ${vs_file} "ipvsm"
	if [ $? -ne 0 ]; then
		createDir ${vs_path}
		if [ $? -ne 0 ];then
			exit 1
		else	# Trying to save agin
			saveFile ${vs_path} ${vs_file} "ipvsm"
		fi
	fi
}

function backup {
	# Saving a backup of rules
	save "backup"
}

function listBackups {
	# TODO list backups
	printf "%sList %s %s%s\n"\
		"${yc[B]}"\
		"${input[ACTION]}"\
		"${input[FLAG]}"\
		"${yc[RESET]}"
}

function setup {

	# Backing up old rules.
	backup

	printf "Setting rules for iptables.\n"
	# Empty all roles for iptables.
	/sbin/iptables -F
	/sbin/iptables -F -t nat
	/sbin/iptables -Z

	printf "Activating forwarding\n"
	# Aktivate forwarding.
	/bin/echo 1 > /proc/sys/net/ipv4/ip_forward

	printf "Aktivate routing between local network and public\n"
	# Aktivate routing between local network and public.
	/sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	/sbin/iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT

	printf "Accepting all trafic from inner network and out\n"
	# Accept all trafic from the inner network and out.
	/sbin/iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT

	printf "Clearing LVS rules\n"
	# Remove LVS rules
	ipvsadm -C

	printf "Setting up round robin with LVS\n"
	# Setting up rount robin
	ipvsadm -A -t 192.168.1.5:80 -s rr
	ipvsadm -a -t 192.168.1.5:80 -r 192.168.76.20 -m
	ipvsadm -a -t 192.168.1.5:80 -r 192.168.76.21 -m
	ipvsadm -a -t 192.168.1.5:80 -r 192.168.76.22 -m

	stop
	start

	return 0
}

function start {
	printf "%sStart NAT%s\n"\
		"${yc[B]}"\
		"${yc[RESET]}"

	# Aktivate forwarding.
	/bin/echo 1 > /proc/sys/net/ipv4/ip_forward

	# Backup old rules
	backup
	# Loading rules
	load
	# Saving rules
	save
}

function stop {
	printf "%sStoping NAT%s\n"\
		"${yc[B]}"\
		"${yc[RESET]}"
	# Saving rules
	save

	# Empty iptable
	/sbin/iptables -F
	/sbin/iptables -F -t nat
	/sbin/iptables -Z

	# Close routing
	/bin/echo 0 > /proc/sys/net/ipv4/ip_forward

	# Remove LVS roules
	ipvsadm -C
}

function load {

	iptables=${backup_iptables[TEMP_PATH]}${backup_iptables[FILE]}
	ipvsm="${backup_ipvsm[TEMP_PATH]}${backup_ipvsm[FILE]}"

	printf "%sLoading iptables rules from file: \n	%s%s%s\n"\
		"${yc[YE]}"\
		"${yc[YE_U]}"\
		"${iptables}"\
		"${yc[RESET]}"
	# restoring iptables rules
	iptables-restore < "${iptables}"

	printf "%sLoading VSL  rules from file: \n	%s%s%s\n"\
		"${yc[YE]}"\
		"${yc[YE_U]}"\
		"${ipvsm}"\
		"${yc[RESET]}"

	# restoring LVS rules
	ipvsadm-restore < "${ipvsm}"
}

function restore {
	# TODO Restore rules from backup files.
	printf "%s\n" "${input[ACTION]}"
	printf "%s\n" "${input[FLAG]}"
	printf "%s\n" "${input[PATH]}"
}

function help {
	# TODO List all actions and flags.
	printf "%s\n" "${input[ACTION]}"
        printf "%s\n" "${input[FLAG]}"
        printf "%s\n" "${input[PATH]}"
	printf "HELP!\n"
}

function argSwitch {
	# Switch between actions.
	arg=$1
	case ${arg} in
		"setup")
			# Setup basic nat rules
			setup
		;;
		"start")
			# Start NAT
			start
		;;
		"stop")
			# Stop NAT
			stop
		;;
		"save")
			# Save rules
			save
		;;
		"restore")
			# Restore ruels from backup
			restore
		;;
		"load")
			# Load active ruels from save file
			load
		;;
		"backup")
			# Backup rules
			if [ "${input[FLAG]}" == "-L" ]; then
				# Listing backups
				listBackups
			else
				# Making backups
				backup
			fi
		;;
		"help")
			# Send help
			help
		;;
		"-h")
			# Send Help
			help
		;;
		"*")
			# Send Help
			help
		;;
	esac
}

# If no args send Help!
if [ "${input[ARG_NUM]}" -eq 0 ]; then
	help
else
	argSwitch ${input[ACTION]}
fi

exit 0
