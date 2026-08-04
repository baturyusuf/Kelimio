#!/bin/sh
set -eu

/usr/local/bin/clamdcheck.sh >/dev/null

latest_definition_epoch=0
for definition in /var/lib/clamav/daily.cvd /var/lib/clamav/daily.cld; do
    if [ -f "$definition" ]; then
        definition_epoch="$(stat -c '%Y' "$definition")"
        if [ "$definition_epoch" -gt "$latest_definition_epoch" ]; then
            latest_definition_epoch="$definition_epoch"
        fi
    fi
done

if [ "$latest_definition_epoch" -eq 0 ]; then
    echo "ClamAV daily definitions are unavailable."
    exit 1
fi

now_epoch="$(date -u '+%s')"
definition_age_seconds="$((now_epoch - latest_definition_epoch))"
maximum_age_seconds="${KELIMIO_CLAMAV_MAX_DEFINITION_AGE_SECONDS:-259200}"
future_skew_seconds="${KELIMIO_CLAMAV_FUTURE_SKEW_SECONDS:-86400}"

if [ "$definition_age_seconds" -gt "$maximum_age_seconds" ] ||
    [ "$definition_age_seconds" -lt "-$future_skew_seconds" ]; then
    echo "ClamAV daily definitions are outside the accepted freshness window."
    exit 1
fi
