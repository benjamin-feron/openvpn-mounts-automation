#!/bin/bash

show_help () {
	echo "Usage: vpn-iut [on|off] [OPTIONS]
	Options:
	--no-mounts     No mounts
	--help          Show help"
}

ACTION="on"
MOUNTS="1"
while :; do
	case $1 in
		on)
			ACTION="on"
			;;
		off)
			ACTION="off"
			;;
		--no-mounts)
			MOUNTS="0"
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

. "$DIR/lib"

if ! [ $(id -u) = 0 ]; then
	throw_error "You must to be root"
fi

if [ ! -f "$DIR/vpn.conf" ]; then
	throw_error "File vpn.conf does not exist."
fi
. "$DIR/vpn.conf"

IFACE=$(cat "$OPENVPN_CONFIG" | grep -e '^dev ' | sed 's/^dev \(.*\)/\1/')
if [ $(echo "$IFACE" | grep -e '[0-9]\+$' | wc -l) == "0" ]; then
	throw_error "You have to name Openvpn interface with number(s) in config file (eg. tun99)."
fi

vpn_off () {
	pkill -SIGTERM -F "$PID_FILE"
	rm "$PID_FILE"
}

mount_on_when_vpn_on () {
	while :
	do
		VPN_ON=$(/bin/netstat -i | grep "$IFACE" | wc -l)
		if [ "$VPN_ON" == "1" ]; then
			$DIR/mount.sh "on"
			break
		fi
		sleep 1
	done
}

vpn_off_when_mount_off () {
	if [ ! -f "$DIR/mount.conf" ]; then
		throw_error "File mount.conf does not exist."
	fi
	. "$DIR/mount.conf"
	while :
	do
		MOUNT_OFF="1"
		for mount in "${MOUNT[@]}"; do
			sysd_file=$(systemd_file "$mount")
			systemctl is-active --quiet "$sysd_file.automount" && MOUNT_OFF=0 && break
		done
		if [ "$MOUNT_OFF" == "1" ]; then
			vpn_off
			break
		fi
		sleep 1
	done
}

case "$ACTION" in
	on)
		openvpn --daemon --writepid "$PID_FILE" --config "$OPENVPN_CONFIG"
		if [ "$MOUNTS" == "1" ]; then
			mount_on_when_vpn_on
		fi
		;;
	off)
		$DIR/mount.sh "off"
		if [ "$MOUNTS" == "1" ]; then
			vpn_off_when_mount_off
		else
			vpn_off
		fi
		;;
esac
