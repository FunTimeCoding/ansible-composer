#!/bin/sh -e

if [ ! -d "${HOME}/venv" ]; then
    python3 -m venv "${HOME}/venv"
fi

# shellcheck source=/dev/null
. "${HOME}/venv/bin/activate"
# Update pip first before even checking the list. List might fail on Stretch since the bundled pip is too old.
pip install --upgrade pip
pip list --outdated
pip install --upgrade --requirement requirements.txt
pip check
