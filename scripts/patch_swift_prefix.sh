#!/usr/bin/env bash
# Inserts `option swift_prefix = "";` after the `package` line in every .proto
# file under vendor/mixi2-api/proto.
#
# Exception: application_stream/v1/service.proto gets `option swift_prefix = "Stream";`
# to avoid a name collision between ApplicationService (API) and ApplicationService (Stream).
#
# Run via: make generate  (called before buf generate, reverted after)

set -euo pipefail

PROTO_DIR="vendor/mixi2-api/proto"
STREAM_PROTO="social/mixi/application/service/application_stream/v1/service.proto"

find "$PROTO_DIR" -name "*.proto" | while read -r proto; do
    relative="${proto#$PROTO_DIR/}"
    if [ "$relative" = "$STREAM_PROTO" ]; then
        prefix='Stream'
    else
        prefix=''
    fi
    # Insert the option line after the first `package ...;` line, only if not already present
    if ! grep -q 'option swift_prefix' "$proto"; then
        sed -i '' "/^package /a\\
option swift_prefix = \"${prefix}\";
" "$proto"
    fi
done

echo "Patched swift_prefix in $PROTO_DIR"
