#!/bin/bash

idrac() {
    local slot=$1
    shift
    local ip=${IDRAC_BASE_IP%.*}.$((${IDRAC_BASE_IP##*.} + $slot))
    local cmd=( $@ )
    local c=idracadm7
    if [[ ${cmd[0]} = job ]]; then
	cmd=( jobqueue create "${cmd[1]}" -r pwrcycle -s TIME_NOW -e TIME_NA )
    fi
    if [[ ${cmd[0]} = vmcli ]]; then
        c=vmcli
        cmd=( ${cmd[@]:1} )
    fi
    "$c" -r "$ip" -u root -p "$IDRAC_PASSWORD" "${cmd[@]}" \
        | egrep -v '^(Security Alert: Certificate|Continuing execution. Use -S)'
}

idrac_all() {
    local s
    local c
    for s in "${IDRAC_ALL_SLOTS[@]}"; do
	echo "blade: $s"
        for c in "$@"; do
	    idrac "$s" $c
        done
    done
}

idrac_serial_comm_settings() {
    idrac_all 'set BIOS.SerialCommSettings.ConTermType Vt100Vt220' \
	'set BIOS.SerialCommSettings.RedirAfterBoot Enabled' \
	'set BIOS.SerialCommSettings.SerialPortAddress Com1' \
	'set BIOS.SerialCommSettings.SerialComm OnConRedir' \
	'set BIOS.SerialCommSettings.FailSafeBaud 115200' \
	'job BIOS.Setup.1-1'
}

idrac_raid_resetconfig() {
    idrac_all 'storage resetconfig:RAID.Integrated.1-1' \
        'job RAID.Integrated.1-1'
}

idrac_raid_jbod() {
    # We know all blades are configured identically:
    local p
    local cmds=()
    local c='raid createvd:RAID.Integrated.1-1 -rl r0 -wp wt -rp nra -ss 64k -pdkey:'
    for p in $(idrac "${IDRAC_ALL_SLOTS[0]}" storage get pdisks | tr -d '\r\n'); do
        cmds+=( "$c$p" )
    done
    idrac_all "${cmds[@]}" \
        'job RAID.Integrated.1-1'
}

idrac_boot_settings() {
    idrac_all 'set BIOS.BiosBootSettings.BootSeq HardDisk.List.1-1' \
        'set BIOS.BiosBootSettings.HddSeq RAID.Integrated.1-1' \
	'job BIOS.Setup.1-1'
}

idrac_vmcli() {
    local slot=$1
    local iso=$2
    idrac "$slot" vmcli -c "$iso" > /dev/null &
}
