#!/bin/sh -e

SYSTEM=$(uname)

if [ "${SYSTEM}" = Darwin ]; then
    GREP='ggrep'
else
    GREP='grep'
fi

export ANSIBLE_CONFIG=tests/ansible.cfg
OUTPUT=$(ansible-playbook tests/test.yaml --inventory=tests/inventory)
RESULT=$(echo "${OUTPUT}" | tail -n 1)
OK=$(echo "${RESULT}" | ${GREP} --only-matching --perl-regexp '(?<=ok=)\d+')
echo "OK: ${OK}"
CHANGED=$(echo "${RESULT}" | ${GREP} --only-matching --perl-regexp '(?<=changed=)\d+')
echo "CHANGED: ${CHANGED}"
UNREACHABLE=$(echo "${RESULT}" | ${GREP} --only-matching --perl-regexp '(?<=unreachable=)\d+')
echo "UNREACHABLE: ${UNREACHABLE}"
FAILED=$(echo "${RESULT}" | ${GREP} --only-matching --perl-regexp '(?<=failed=)\d+')
echo "FAILED: ${FAILED}"
FAIL=false

if [ "${UNREACHABLE}" -gt 0 ]; then
    FAIL=true
fi

if [ "${FAILED}" -gt 0 ]; then
    FAIL=true
fi

if [ "${FAIL}" = true ]; then
    exit 1
fi
