#!/usr/bin/env bash
# The update test (Roostack's docs/REGISTRY-UPDATES.md): boots a throwaway
# Debian 13 VM, installs the released Roostack on it, and has drive.py
# install a package's previous version, back it up, update it, and restore
# it, as a lab would.
#
#   .github/update-test/run.sh <package> <from> <to>
#
# <from> is empty when labs can't install any version now (from.sh).
# Run from the registry's root, on Linux with KVM and QEMU. The VM's disk
# and key are in a temporary folder, removed at the end. IMAGE_CACHE is a
# folder to keep the downloaded Debian image in, and KEEP_VM=1 leaves the VM
# running to look at (ssh details are printed).
set -euo pipefail
pkg=${1:?package} from=${2?version to update from, or empty} to=${3:?version to update to}
here=$(cd "$(dirname "$0")" && pwd)
dir=$(mktemp -d)
ssh_port=${SSH_PORT:-2299} seed_port=${SEED_PORT:-18999} ui_port=${UI_PORT:-18899}
cache=${IMAGE_CACHE:-$dir}
base_url=https://cloud.debian.org/images/cloud/trixie/latest
image=debian-13-genericcloud-amd64.qcow2

finish() {
	status=$?
	if [ "${KEEP_VM:-}" = 1 ]; then
		echo "The VM is still running: ssh -i $dir/key -p $ssh_port -o StrictHostKeyChecking=no tester@127.0.0.1"
		exit "$status"
	fi
	[ -z "${seed_pid:-}" ] || kill "$seed_pid" 2>/dev/null || true
	[ ! -f "$dir/pid" ] || kill "$(cat "$dir/pid")" 2>/dev/null || true
	rm -rf "$dir"
	exit "$status"
}
trap finish EXIT

if [ ! -f "$cache/$image" ]; then
	mkdir -p "$cache"
	curl -fsSL --retry 3 -o "$cache/$image.part" "$base_url/$image"
	want=$(curl -fsSL --retry 3 "$base_url/SHA512SUMS" | awk -v f="$image" '$2 == f {print $1}')
	[ "$(sha512sum "$cache/$image.part" | awk '{print $1}')" = "$want" ] || { echo "The Debian image's checksum doesn't match." >&2; exit 1; }
	mv "$cache/$image.part" "$cache/$image"
fi

cp --reflink=auto "$cache/$image" "$dir/disk.qcow2"
ssh-keygen -q -t ed25519 -N '' -f "$dir/key"
mkdir "$dir/seed"
printf 'instance-id: update-test\nlocal-hostname: update-test\n' >"$dir/seed/meta-data"
: >"$dir/seed/vendor-data"
cat >"$dir/seed/user-data" <<SEED
#cloud-config
users:
  - name: tester
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - $(cat "$dir/key.pub")
ssh_pwauth: false
SEED
(cd "$dir/seed" && exec python3 -m http.server "$seed_port" --bind 127.0.0.1 >/dev/null 2>&1) &
seed_pid=$!

qemu-system-x86_64 -name update-test -machine q35,accel=kvm -cpu host -m "${VM_MEMORY:-10240}" -smp "${VM_CPUS:-4}" \
	-drive "file=$dir/disk.qcow2,if=virtio,id=disk0" \
	-netdev "user,id=net0,hostfwd=tcp:127.0.0.1:$ssh_port-:22" \
	-device virtio-net-pci,netdev=net0 -device virtio-rng-pci \
	-smbios "type=1,serial=ds=nocloud;s=http://10.0.2.2:$seed_port/" \
	-display none -serial "file:$dir/console.log" -qmp "unix:$dir/qmp,server=on,wait=off" -S -daemonize -pidfile "$dir/pid"
# Started paused, so the disk can grow before the guest boots.
python3 - "$dir/qmp" <<'QMP'
import json, socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
f = s.makefile("rw")
f.readline()
for cmd in ({"execute": "qmp_capabilities"},
            {"execute": "block_resize", "arguments": {"device": "disk0", "size": 40 << 30}},
            {"execute": "cont"}):
    f.write(json.dumps(cmd) + "\n")
    f.flush()
    while True:
        msg = json.loads(f.readline())
        if "event" in msg:
            continue
        if "error" in msg:
            sys.exit("QEMU: " + msg["error"]["desc"])
        break
QMP

export UPDATE_TEST_SSH="ssh -i $dir/key -p $ssh_port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 tester@127.0.0.1"
for _ in $(seq 1 90); do
	$UPDATE_TEST_SSH true 2>/dev/null && break
	sleep 5
done
$UPDATE_TEST_SSH 'cloud-init status --wait >/dev/null; sudo apt-get update -qq; sudo apt-get install -y -qq curl ca-certificates >/dev/null'
$UPDATE_TEST_SSH "curl -fsSL ${ROOSTACK_INSTALL_URL:-https://dl.roostack.cloud/install.sh} | sudo sh" >/dev/null

# Roostack's pages are only on the VM's own loopback.
$UPDATE_TEST_SSH -f -N -L "127.0.0.1:$ui_port:127.0.0.1:8480"
python3 "$here/drive.py" --ui "http://127.0.0.1:$ui_port" --package "$pkg" --from "$from" --to "$to" --repo .
