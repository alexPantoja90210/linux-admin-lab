#!/usr/bin/env bash
# Gives a freshly cloned VM its own identity: host name, machine-id and
# Red Hat subscription identity.
#
# Usage: sudo bash generalize-clone.sh <new-hostname>
#
# Never use "subscription-manager register --force" on a clone: it would
# unregister the identity inherited from the template, which belongs to
# the template itself.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash $0 <new-hostname>" >&2
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Usage: sudo bash $0 <new-hostname>" >&2
    exit 1
fi

new_hostname="$1"
old_machine_id="$(cat /etc/machine-id 2>/dev/null || echo none)"

echo "==> Host name: $(hostname) -> $new_hostname"
hostnamectl set-hostname "$new_hostname"

echo "==> Regenerating machine-id"
rm -f /etc/machine-id
systemd-machine-id-setup
new_machine_id="$(cat /etc/machine-id)"
if [[ "$new_machine_id" == "$old_machine_id" ]]; then
    echo "machine-id did not change" >&2
    exit 1
fi

if command -v subscription-manager >/dev/null 2>&1; then
    echo "==> Replacing the inherited Red Hat identity (local data only)"
    subscription-manager clean
    echo "==> Registering this system (enter your Red Hat credentials)"
    subscription-manager register
    subscription-manager identity
fi

echo
echo "Done."
echo "  host name : $(hostnamectl --static)"
echo "  machine-id: $new_machine_id (was $old_machine_id)"
ip -4 -brief addr show scope global
echo "Log out and back in to see the new host name in the prompt."
