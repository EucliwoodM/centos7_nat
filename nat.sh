#!/usr/bin/env bash

declare -A input
declare -A backup_iptables
declare -A backup_ipvsm
declare -A color

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

# Basic color palet.
color[RE]="$(tput setaf 1)"		# Set red text.
color[GR]="$(tput setaf 2)"		# Set green text.
color[YE]="$(tput setaf 3)"		# Set yellow text.
color[DB]="$(tput setaf 4)"		# Set dark blue text.
color[PU]="$(tput setaf 5)"		# Set purple text.
color[LB]="$(tput setaf 6)"		# Set light blue text.
color[WH]="$(tput setaf 7)"		# Set white text.
color[B]="$(tput bold)"			# Set bold text.
color[U]="$(tput sgr 0 1)"		# Set underline text.
color[UB]="${color[U]} ${color[B]}"	# Set underline and bold text.

# Set bold and color.
color[RE_B]="${color[RESET]}${color[B]}${color[RE]}"
color[GR_B]="${color[RESET]}${color[B]}${color[GR]}"
color[YE_B]="${color[RESET]}${color[B]}${color[YE]}"
color[DB_B]="${color[RESET]}${color[B]}${color[DB]}"
color[PU_B]="${color[RESET]}${color[B]}${color[PU]}"
color[LB_B]="${color[RESET]}${color[B]}${color[LB]}"
color[WH_B]="${color[RESET]}${color[B]}${color[WH]}"

# Set underline and color.
color[RE_U]="${color[RESET]}${color[U]}${color[RE]}"
color[GR_U]="${color[RESET]}${color[U]}${color[GR]}"
color[YE_U]="${color[RESET]}${color[U]}${color[YE]}"
color[DB_U]="${color[RESET]}${color[U]}${color[DB]}"
color[PU_U]="${color[RESET]}${color[U]}${color[PU]}"
color[LB_U]="${color[RESET]}${color[U]}${color[LB]}"
color[WH_U]="${color[RESET]}${color[U]}${color[WH]}"

# Set underline, bold and color.
color[RE_UB]="${color[RESET]}${color[UB]}${color[RE]}"
color[GR_UB]="${color[RESET]}${color[UB]}${color[GR]}"
color[YE_UB]="${color[RESET]}${color[UB]}${color[YE]}"
color[DB_UB]="${color[RESET]}${color[UB]}${color[DB]}"
color[PU_UB]="${color[RESET]}${color[UB]}${color[PU]}"
color[LB_UB]="${color[RESET]}${color[UB]}${color[LB]}"
color[WH_UB]="${color[RESET]}${color[UB]}${color[WH]}"

# RESET colors and font.
color[RESET]="$(tput sgr0)"

# Check if script is run by root.
function checkRoot {
	if [ "$EUID" -ne 0 ]; then
		printf "%sYou need to run as %sroot. %s\n"\
			"${color[RE]}"\
			"${color[RE_B]}"\
			"${color[RESET]}"
		return 1
	else
		printf "%sYou run as %sroot. %s\n"\
			"${color[GR]}"\
			"${color[GR_B]}"\
			"${color[RESET]}"
		return 0
	fi
}

# Create backup dir.
function createDir {

	temp_path=$1
	mkdir -p ${temp_path}
	if [ $? -eq 0 ]; then
		printf "%sCreated backup dir: \n%s%s%s\n"\
			"${color[GR]}"\
			"${color[GR_U]}"\
			"	${temp_path}"\
			"${color[RESET]}"
		return 0
	else
		printf "%sFailed during: \n%smkdir %s%s%s\n"\
			"${color[RE]}"\
			"${color[RE_B]}"\
			"${color[RE_U]}"\
			"	${temp_path}"\
			"${color[RESET]}"
		return 1
	fi
}

# Save rules to file
function saveFile {
	
	temp_path=$1
	full_path=$1$2
	rules=$3
	
	printf "%sSaving %s%s\n"\
		 "${color[B]}"\
		 "${rules}"\
		 "${color[RESET]}"

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
			"${color[GR]}"\
			"${color[GR_U]}"\
			"	${full_path}"\
			"${color[RESET]}"
		return 0
	else
		printf "%sFailed to find path: \n%s%s%s\n"\
			"${color[RE]}"\
			"${color[RE_U]}"\
			"	${temp_path}"\
			"${color[RESET]}"

		printf "%sFailed create file: \n%s%s%s\n"\
			"${color[RE]}"\
			"${color[RE_U]}"\
			"	${full_path}"\
			"${color[RESET]}"
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
		"${color[B]}"\
		"${input[ACTION]}"\
		"${input[FLAG]}"\
		"${color[RESET]}"
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
		"${color[B]}"\
		"${color[RESET]}"
	
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
		"${color[B]}"\
		"${color[RESET]}"
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
		"${color[YE]}"\
		"${color[YE_U]}"\
		"${iptables}"\
		"${color[RESET]}"
	# restoring iptables rules
	iptables-restore < "${iptables}"
	
	printf "%sLoading VSL  rules from file: \n	%s%s%s\n"\
		"${color[YE]}"\
		"${color[YE_U]}"\
		"${ipvsm}"\
		"${color[RESET]}"
	
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
