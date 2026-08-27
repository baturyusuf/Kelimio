#!/bin/sh
set -eu

# Refresh before accepting scans so the worker health gate never observes the
# definitions baked into the image as if they were current production data.
freshclam --foreground --stdout --user=clamav

# Keep signatures current for a long-lived scaled-up worker task. clamd stays
# in the foreground so Fargate can supervise the container directly.
freshclam \
  --checks="${FRESHCLAM_CHECKS:-24}" \
  --daemon \
  --foreground \
  --stdout \
  --user=clamav &

exec clamd --foreground
