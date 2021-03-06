#!/bin/sh -e

DIRECTORY=$(dirname "${0}")
SCRIPT_DIRECTORY=$(cd "${DIRECTORY}" || exit 1; pwd)
# shellcheck source=/dev/null
. "${SCRIPT_DIRECTORY}/../lib/common.sh"

if [ "${1}" = --help ]; then
    echo "Usage: ${0} [--ci-mode]"

    exit 0
fi

CONCERN_FOUND=false
CONTINUOUS_INTEGRATION_MODE=false

if [ "${1}" = --ci-mode ]; then
    shift
    mkdir -p build/log
    CONTINUOUS_INTEGRATION_MODE=true
fi

SYSTEM=$(uname)

if [ "${SYSTEM}" = Darwin ]; then
    FIND='gfind'
else
    FIND='find'
fi

TEMPORARY_DIRECTORY="${HOME}/tmp"
UPDATE_FILE="${TEMPORARY_DIRECTORY}/last-venv-update.txt"

if [ ! -f "${UPDATE_FILE}" ]; then
    mkdir -p "${TEMPORARY_DIRECTORY}"
    touch "${UPDATE_FILE}"
    script/python/update.sh
fi

if test "$(${FIND} "${UPDATE_FILE}" -mmin +300)"; then
    touch "${UPDATE_FILE}"
    script/python/update.sh
fi

MARKDOWN_FILES=$(${FIND} . -regextype posix-extended -name '*.md' ! -regex "${EXCLUDE_FILTER}" -printf '%P\n')
BLACKLIST=''
DICTIONARY=en_US
mkdir -p tmp

if [ -d documentation/dictionary ]; then
    cat documentation/dictionary/*.dic > tmp/combined.dic
else
    touch tmp/combined.dic
fi

for FILE in ${MARKDOWN_FILES}; do
    WORDS=$(hunspell -d "${DICTIONARY}" -p tmp/combined.dic -l "${FILE}" | sort | uniq)

    if [ ! "${WORDS}" = '' ]; then
        echo "${FILE}"

        for WORD in ${WORDS}; do
            BLACKLISTED=$(echo "${BLACKLIST}" | grep "${WORD}") || BLACKLISTED=false

            if [ "${BLACKLISTED}" = false ]; then
                if [ "${CONTINUOUS_INTEGRATION_MODE}" = true ]; then
                    grep --line-number "${WORD}" "${FILE}"
                else
                    # The equals character is required.
                    grep --line-number --color=always "${WORD}" "${FILE}"
                fi
            else
                echo "Blacklisted word: ${WORD}"
            fi
        done

        echo
    fi
done

TEX_FILES=$(${FIND} . -regextype posix-extended -name '*.tex' ! -regex "${EXCLUDE_FILTER}" -printf '%P\n')

for FILE in ${TEX_FILES}; do
    WORDS=$(hunspell -d "${DICTIONARY}" -p tmp/combined.dic -l -t "${FILE}")

    if [ ! "${WORDS}" = '' ]; then
        echo "${FILE}"

        for WORD in ${WORDS}; do
            STARTS_WITH_DASH=$(echo "${WORD}" | grep -q '^-') || STARTS_WITH_DASH=false

            if [ "${STARTS_WITH_DASH}" = false ]; then
                BLACKLISTED=$(echo "${BLACKLIST}" | grep "${WORD}") || BLACKLISTED=false

                if [ "${BLACKLISTED}" = false ]; then
                    if [ "${CONTINUOUS_INTEGRATION_MODE}" = true ]; then
                        grep --line-number "${WORD}" "${FILE}"
                    else
                        # The equals character is required.
                        grep --line-number --color=always "${WORD}" "${FILE}"
                    fi
                else
                    echo "Skip blacklisted: ${WORD}"
                fi
            else
                echo "Skip invalid: ${WORD}"
            fi
        done

        echo
    fi
done

if [ "${CONTINUOUS_INTEGRATION_MODE}" = true ]; then
    FILES=$(${FIND} . -regextype posix-extended -name '*.sh' ! -regex "${EXCLUDE_FILTER}" -printf '%P\n')

    for FILE in ${FILES}; do
        FILE_REPLACED=$(echo "${FILE}" | sed 's/\//-/g')
        shellcheck --format checkstyle "${FILE}" > "build/log/checkstyle-${FILE_REPLACED}.xml" || true
    done
else
    # shellcheck disable=SC2016
    SHELL_SCRIPT_CONCERNS=$(${FIND} . -name '*.sh' -regextype posix-extended ! -regex "${EXCLUDE_FILTER}" -exec sh -c 'shellcheck ${1} || true' '_' '{}' \;)

    if [ ! "${SHELL_SCRIPT_CONCERNS}" = '' ]; then
        CONCERN_FOUND=true
        echo "[WARNING] Shell script concerns:"
        echo "${SHELL_SCRIPT_CONCERNS}"
    fi
fi

# shellcheck disable=SC2016
EMPTY_FILES=$(${FIND} . -regextype posix-extended -type f -empty ! -regex "${EXCLUDE_FILTER}")

if [ ! "${EMPTY_FILES}" = '' ]; then
    CONCERN_FOUND=true

    if [ "${CONTINUOUS_INTEGRATION_MODE}" = true ]; then
        echo "${EMPTY_FILES}" > build/log/empty-files.txt
    else
        echo
        echo "[WARNING] Empty files:"
        echo
        echo "${EMPTY_FILES}"
    fi
fi

# shellcheck disable=SC2016
TO_DOS=$(${FIND} . -regextype posix-extended -type f ! -regex "${EXCLUDE_FILTER}" -exec sh -c 'grep -Hrn TODO "${1}" | grep -v "${2}"' '_' '{}' '${0}' \;)

if [ ! "${TO_DOS}" = '' ]; then
    if [ "${CONTINUOUS_INTEGRATION_MODE}" = true ]; then
        echo "${TO_DOS}" > build/log/to-dos.txt
    else
        echo
        echo "[NOTICE] To dos:"
        echo
        echo "${TO_DOS}"
    fi
fi

# shellcheck disable=SC2016
SHELLCHECK_IGNORES=$(${FIND} . -regextype posix-extended -type f ! -regex "${EXCLUDE_FILTER}" -exec sh -c 'grep -Hrn "# shellcheck" "${1}" | grep -v "${2}"' '_' '{}' '${0}' \;)

if [ ! "${SHELLCHECK_IGNORES}" = '' ]; then
    if [ "${CONTINUOUS_INTEGRATION_MODE}" = true ]; then
        echo "${SHELLCHECK_IGNORES}" > build/log/shellcheck-ignores.txt
    else
        echo
        echo "[NOTICE] Shellcheck ignores:"
        echo
        echo "${SHELLCHECK_IGNORES}"
    fi
fi

RETURN_CODE=0
export ANSIBLE_CONFIG=tests/ansible.cfg
ANSIBLE_CHECK_CONCERNS=$(ansible-playbook tests/test.yaml --inventory=tests/inventory --syntax-check) || RETURN_CODE=$?

if [ ! "${RETURN_CODE}" = '0' ]; then
    if [ "${CONTINUOUS_INTEGRATION_MODE}" = true ]; then
        echo "${ANSIBLE_CHECK_CONCERNS}" > build/log/ansible-check.txt
    else
        echo
        echo "[NOTICE] Ansible check concerns:"
        echo
        echo "${ANSIBLE_CHECK_CONCERNS}"
    fi
fi

# shellcheck source=/dev/null
. "${HOME}/venv/bin/activate"
RETURN_CODE=0
ANSIBLE_LINT_CONCERNS=$(ansible-lint --nocolor --parseable-severity tests/test.yaml) || RETURN_CODE=$?

if [ ! "${RETURN_CODE}" = '0' ]; then
    CONCERN_FOUND='true'

    if [ "${CONTINUOUS_INTEGRATION_MODE}" = true ]; then
        echo "${ANSIBLE_LINT_CONCERNS}" > build/log/ansible-lint.txt
    else
        echo
        echo "[WARNING] Ansible lint concerns:"
        echo
        echo "${ANSIBLE_LINT_CONCERNS}"
    fi
fi

if [ "${CONCERN_FOUND}" = true ]; then
    if [ "${CONTINUOUS_INTEGRATION_MODE}" = false ]; then
        echo
        echo "Concern(s) of category WARNING found." >&2
    fi

    exit 2
fi
