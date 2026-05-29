#!/bin/sh
set -e

/app/transport-auth &
exec nginx -g 'daemon off;'
