#!/bin/bash

show_help () {
        echo "Usage: vpn-iut [on|off] [OPTIONS]
        *Options:
        on            Enable (by default)
        off           Disable
        --help        Show help"
}

ACTION="on"

while :; do
	case $1 in
		on)
			ACTION="on"
			;;
		off)
			ACTION="off"
			;;
		--help)
			show_help
			exit
			;;
		-?*)
			printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
			;;
		*)
			break
	esac
	shift
done

script_dir () {
	SOURCE="${BASH_SOURCE[0]}"
	while [ -h "$SOURCE" ]; do
		DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
		SOURCE="$(readlink "$SOURCE")"
		[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
	done
	echo "$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
}

DIR="$(script_dir)"

if [ ! -f "$DIR/mount.conf" ]; then
	throw_error "File mount.conf does not exist."
fi

declare -A MOUNT
. "$DIR/mount.conf"
. "$DIR/lib"

case "$ACTION" in
	on)
		reverse_array MOUNT MOUNT_R
		for mount in "${MOUNT_R[@]}"; do
			sysd_file="$(systemd_file "$mount").automount"
			echo "démarrage de $sysd_file"
			systemctl start "$sysd_file"
			sleep 1
		done
		;;
	off)
		for mount in "${MOUNT[@]}"; do
			sysd_file="$(systemd_file "$mount").automount"
			echo "arrêt de $sysd_file"
			systemctl stop "$sysd_file"
		done
		;;
esac

