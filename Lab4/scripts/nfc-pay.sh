#!/bin/sh
set -e

PORT="$1"
AMOUNT="${2:-65}"
TERMINAL="${3:-TERM-001}"

if [ -z "$PORT" ]; then
  echo "Usage: ./scripts/nfc-pay.sh /dev/cu.usbserial-XXXX [amount] [terminal]"
  exit 1
fi

cd "$(dirname "$0")/../pn532_cli"
dart pub get
dart run bin/pn532_pay.dart \
  --port "$PORT" \
  --api https://localhost:8888/api/v1 \
  --terminal "$TERMINAL" \
  --amount "$AMOUNT" \
  --username admin \
  --password admin123
