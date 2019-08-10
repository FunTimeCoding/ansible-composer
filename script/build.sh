#!/bin/sh -e

rm -rf build
# TODO: Make the ansible-provisioning repository with all role dependencies available globally. Either in /etc/ansible or somewhere in the CI user. Have all ansible role test jobs update it before checking ansible.
script/check.sh --ci-mode
# TODO: Make sure that this will be non-destructive and non-cluttering on the CI node.
#script/ansible/test.sh
