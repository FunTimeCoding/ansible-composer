#!/bin/sh -e

# vendor is in here to not break php-skeleton based projects when synchronizing with them.
EXCLUDE_FILTER='^.*/(build|tmp|vendor|\.git|\.vagrant|\.idea|\.venv)/.*$'
export EXCLUDE_FILTER
