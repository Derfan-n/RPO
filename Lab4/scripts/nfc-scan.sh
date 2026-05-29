#!/bin/sh
set -e

PORT="$1"
if [ -z "$PORT" ]; then
  echo "Usage: ./scripts/nfc-scan.sh /dev/cu.usbserial-XXXX"
  exit 1
fi

cd "$(dirname "$0")/../pn532_cli"
dart pub get
dart run bin/pn532_cli.dart scan --port "$PORT"
