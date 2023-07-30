#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p nix jq yq
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

# Finds the characteristic with the given iid in the accessory with the given aid.
# Returns the characteristic surrounded by its service.

aid=$1
iid=$2

for f in $(find ./accessories -name '*.toml'); do
    if [ "$(./util/aid.sh "$f")" == "$aid" ]; then
        service_with_characteristic=$(./util/validate-toml.sh "$f" | jq -c '.services | .[]' | ./util/generate-service.sh | jq -c ".characteristics |= map(select(.iid == $iid)) | select(.characteristics | any)")
        if [ "$service_with_characteristic" != "" ]; then
            echo "$service_with_characteristic";
            exit 0
        fi
    fi
done
echo "Characteristic $iid from accessory $aid not found!" >&2
exit 1