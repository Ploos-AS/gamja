#!/bin/sh
set -eu

tag=${1:-}

if [ -z "$tag" ]; then
    echo "usage: $0 vMAJOR.MINOR.PATCH[-PRERELEASE]" >&2
    exit 2
fi

# OCI/Docker tags cannot contain SemVer build metadata (+...). Keep release
# refs intentionally stricter than generic SemVer so every accepted Git tag
# maps losslessly to the published image tag.
case "$tag" in
    v0|v0.*) ;;
    v[1-9][0-9]*|v[1-9][0-9]*.*) ;;
    *)
        echo "invalid release tag: $tag" >&2
        exit 1
        ;;
esac

if ! printf '%s\n' "$tag" | grep -Eq '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'; then
    echo "invalid release tag: $tag" >&2
    exit 1
fi

# SemVer numeric prerelease identifiers must not contain leading zeroes.
prerelease=${tag#*-}
if [ "$prerelease" != "$tag" ]; then
    old_ifs=$IFS
    IFS=.
    for identifier in $prerelease; do
        case "$identifier" in
            '' )
                echo "invalid empty prerelease identifier: $tag" >&2
                IFS=$old_ifs
                exit 1
                ;;
            *[!0-9]* ) ;;
            0 ) ;;
            0* )
                echo "numeric prerelease identifier has a leading zero: $tag" >&2
                IFS=$old_ifs
                exit 1
                ;;
        esac
    done
    IFS=$old_ifs
fi

printf '%s\n' "${tag#v}"
