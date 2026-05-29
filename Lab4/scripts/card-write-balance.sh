#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-}"
BALANCE="${2:-}"
if [[ -z "$PORT" || -z "$BALANCE" ]]; then
  echo "Usage: ./scripts/card-write-balance.sh /dev/cu.usbserial-XXXX 500"
  exit 1
fi

if ! [[ "$BALANCE" =~ ^[0-9]+$ ]]; then
  echo "Balance must be a non-negative integer"
  exit 1
fi

cd "$(dirname "$0")/.."
mkdir -p tmp
export LIBNFC_DEFAULT_DEVICE="pn532_uart:$PORT"

echo "Положи карту на PN532 и держи её до завершения команды."
echo "1/3 Reading current card dump..."
nfc-mfclassic r A u tmp/card_dump_before_write.mfd

echo "2/3 Preparing modified dump with BAL:$BALANCE in block 4..."
python3 - "$BALANCE" <<'PY'
from pathlib import Path
import sys
balance = int(sys.argv[1])
base = Path('tmp/card_dump_before_write.mfd')
data = bytearray(base.read_bytes())
payload = f'BAL:{balance}'.encode('ascii')
if len(payload) > 16:
    raise SystemExit('Balance is too large for one block')
offset = 4 * 16
data[offset:offset+16] = payload.ljust(16, b'\x00')
Path('tmp/card_dump_modified.mfd').write_bytes(data)
print('Prepared block 4:', payload.decode())
PY

echo "3/3 Writing modified dump back to card..."
nfc-mfclassic w A u tmp/card_dump_modified.mfd tmp/card_dump_before_write.mfd

echo "Done. Verify with: ./scripts/card-read-balance.sh $PORT"
