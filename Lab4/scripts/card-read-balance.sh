#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-}"
if [[ -z "$PORT" ]]; then
  echo "Usage: ./scripts/card-read-balance.sh /dev/cu.usbserial-XXXX"
  exit 1
fi

cd "$(dirname "$0")/.."
mkdir -p tmp
export LIBNFC_DEFAULT_DEVICE="pn532_uart:$PORT"

echo "Положи карту на PN532 и держи её до завершения команды."
echo "Reading full MIFARE Classic dump..."
nfc-mfclassic r A u tmp/card_dump_read.mfd

python3 - <<'PY'
from pathlib import Path
p = Path('tmp/card_dump_read.mfd')
data = p.read_bytes()
raw = data[4*16:4*16+16]
text = raw.split(b'\x00', 1)[0].decode('ascii', errors='replace').strip()
print('Block 4 raw:', raw)
print('Block 4 text:', text or '(empty)')
if text.startswith('BAL:'):
    print('Balance:', text[4:])
else:
    print('Balance not found. Expected format: BAL:500')
PY
