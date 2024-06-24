#!/usr/bin/env bash

# -------------------------------------------------------------------------------- #
# Description                                                                      #
# -------------------------------------------------------------------------------- #
# This script will locate and process all relevant files within the given git      #
# repository. Errors will be stored and a final exit status used to show if a      #
# failure occurred during the processing.                                          #
# -------------------------------------------------------------------------------- #

# -------------------------------------------------------------------------------- #
# Configure the shell.                                                             #
# -------------------------------------------------------------------------------- #

set -Eeuo pipefail

# -------------------------------------------------------------------------------- #
# Global Variables                                                                 #
# -------------------------------------------------------------------------------- #

# Are you using a perl based tool?
PERL_BASED_TOOL=false

# Are you using a python based tool?
PYTHON_BASED_TOOL=false
INSTALL_REQUIREMENTS=false

# Are you using a ruby gem based tool?
RUBY_GEM_BASED_TOOL=false
RUBY_GEM_NAME=''

# Are you using a docker based tool?
DOCKER_BASED_TOOL=false
DOCKER_CONTAINER=''
DOCKER_CONTAINER_SHORT=''

# How to install the require tool - eg gem install or pip install
INSTALL_COMMAND=('sudo' 'apt-get' '-qq' '-y' 'install' 'jq')

# The specific command to run when running a test
TEST_COMMAND=('jq')

# Version Banner - What to show on the version banned
BANNER_NAME="${TEST_COMMAND[*]}"

# File type to match (comes from file -b) [Regex based]
FILE_TYPE_SEARCH_PATTERN='^JSON'

# File name to match [Regex based]
FILE_NAME_SEARCH_PATTERN='\.json'

# Set where to look for files.
SCAN_ROOT='.'

# -------------------------------------------------------------------------------- #
# Script Specific Global Variables                                                 #
# -------------------------------------------------------------------------------- #
#
# Add anything specific to this tool here
#

# -------------------------------------------------------------------------------- #
# Tool Specific Functions                                                          #
# -------------------------------------------------------------------------------- #

function handle_non_standard_parameters()
{
    local parameters=false
    local retval=0


    if [[ "${parameters}" != true ]]; then
        retval=1
    fi

    return "${retval}"
}

function check_file()
{
    local filename=$1
    local errors

    file_count=$((file_count + 1))
    # shellcheck disable=SC2310
    if ! errors=$(run_command "${TEST_COMMAND[@]}" < "${filename}"); then
        fail "${filename}" "${errors}"
        fail_count=$((fail_count + 1))
    else
        success "${filename}"
        ok_count=$((ok_count + 1))
    fi
}

# -------------------------------------------------------------------------------- #
# Stop Here                                                                        #
#                                                                                  #
# Everything below here is standard and designed to work with all of the tools     #
# that have been built and released as part of the CICDToolbox.                    #
# -------------------------------------------------------------------------------- #

EXIT_VALUE=0
CURRENT_STAGE=0

# -------------------------------------------------------------------------------- #
# Utility Functions                                                                #
# -------------------------------------------------------------------------------- #

function run_command()
{
    local command=("$@")

    if ! output=$("${command[@]}" 2>&1); then
        echo "${output}"
        return 1
    fi
    echo "${output}"
    return 0
}

function stage()
{
    local message=${1:-}

    CURRENT_STAGE=$((CURRENT_STAGE + 1))
    align_right "${bold_text}${cyan_text}Stage ${CURRENT_STAGE}: ${message}${reset}"
}

function success()
{
    local message=${1:-}

    echo " [ ${bold_text}${green_text}OK${reset} ] ${message}"
}

function fail()
{
    local message=${1:-}
    local errors=${2:-}
    local override=${3:-false}

    echo " [ ${bold_text}${red_text}FAIL${reset} ] ${message}"

    if [[ "${SHOW_ERRORS}" == true || "${override}" == true ]]; then
        if [[ -n "${errors}" ]]; then
            echo
            echo "${errors}" | while IFS= read -r err; do
                echo "          ${err}"
            done
            echo
        fi
    fi

    EXIT_VALUE=1
}

function skip()
{
    local message=${1:-}

    if [[ "${SHOW_SKIPPED}" == true ]]; then
        skip_count=$((skip_count + 1))
        echo " [ ${bold_text}${yellow_text}Skip${reset} ] ${message}"
    fi
}

function is_excluded()
{
    local needle=$1

    for pattern in "${exclude_list[@]}"; do
        if [[ "${needle}" =~ ${pattern} ]]; then
            return 0
        fi
    done
    return 1
}

function is_included()
{
    local needle=$1

    for pattern in "${include_list[@]}"; do
        if [[ "${needle}" =~ ${pattern} ]]; then
            return 0
        fi
    done
    return 1
}

function align_right()
{
    local message=${1:-}
    local offset=${2:-2}
    local width=${screen_width}

    local clean
    clean=$(strip_colours "${message}")
    local textsize=${#clean}

    local left_line='-' left_width=$((width - (textsize + offset + 2)))
    local right_line='-' right_width=${offset}

    while ((${#left_line} < left_width)); do left_line+="${left_line}"; done
    while ((${#right_line} < right_width)); do right_line+="${right_line}"; done

    printf '%s %s %s\n' "${left_line:0:left_width}" "${message}" "${right_line:0:right_width}"
}

function strip_colours()
{
    local orig=${1:-}

    if ! shopt -q extglob; then
        shopt -s extglob
        local on=true
    fi
    local clean="${orig//$'\e'[\[(]*([0-9;])[@-n]/}"
    [[ "${on}" == true ]] && shopt -u extglob
    echo "${clean}"
}

# -------------------------------------------------------------------------------- #
# Core Functions                                                                   #
# -------------------------------------------------------------------------------- #

function install_prerequisites()
{
    local pip_update=('python' '-m' 'pip' 'install' '--quiet' '--upgrade' 'pip')

    stage 'Install Prerequisites'

    if [[ "${PYTHON_BASED_TOOL}" = true ]] ; then
        # shellcheck disable=SC2310
        if ! errors=$(run_command "${pip_update[@]}"); then
            fail "${pip_update[*]}" "${errors}" true
            exit "${EXIT_VALUE}"
        else
            success "${pip_update[*]}"
        fi
    fi

    if [[ "${DOCKER_BASED_TOOL}" = true ]] ; then
        # shellcheck disable=SC2310
        if ! errors=$(run_command "${INSTALL_COMMAND[@]}"); then
            fail "${INSTALL_COMMAND[*]}" "${errors}" true
            exit "${EXIT_VALUE}"
        else
            success "${INSTALL_COMMAND[*]}"
        fi
    else
        if ! "${TEST_COMMAND[@]}" --help &> /dev/null; then
            # shellcheck disable=SC2310
            if ! errors=$(run_command "${INSTALL_COMMAND[@]}"); then
                fail "${INSTALL_COMMAND[*]}" "${errors}" true
                exit "${EXIT_VALUE}"
            else
                success "${INSTALL_COMMAND[*]}"
            fi
        else
            success "${TEST_COMMAND[*]} is already installed"
        fi
    fi

    if [[ "${INSTALL_REQUIREMENTS}" = true ]] ; then
        while IFS= read -r filename
        do
            CMD=("pip" "install" "-r" "${filename}")
            # shellcheck disable=SC2310
            if errors=$(run_command "${CMD[@]}" ); then
                success "${CMD[*]}"
            else
                fail "${CMD[*]}" "${errors}" true
                exit "${EXIT_VALUE}"
            fi
        done < <(find . -name 'requirements*.txt' -type f -not -path "./.git/*" | sed 's|^./||' | sort -Vf || true)
    fi
}

function get_version_information()
{
    local output

    if [[ "${RUBY_GEM_BASED_TOOL}" = true ]] ; then
        output=$(run_command gem list | grep "^${RUBY_GEM_NAME} " | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')
    elif [[ "${PYTHON_BASED_TOOL}" = true ]] ; then
        output=$(run_command "${TEST_COMMAND[@]}" --version)
        output=$(echo "${output}" | tr -d '\n' | head -n 1 | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')
    elif [[ "${DOCKER_BASED_TOOL}" = true ]] ; then
        output=$(run_command docker run "${DOCKER_CONTAINER}" "${DOCKER_CONTAINER_SHORT}" --version)
        output=$(echo "${output}" | tr -d '\n' | head -n 1 | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')
    elif [[ "${PERL_BASED_TOOL}" = true ]] ; then
        output=$(run_command "${TEST_COMMAND[@]}" -e 'print substr($^V, 1)')
    else
        output=$(run_command "${TEST_COMMAND[@]}" --version)
        output=$(echo "${output}" | tr -d '\n' | head -n 1 | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')
    fi

    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]]; then
        echo "Failed to get version information."
        return 1
    fi

    VERSION="${output}"
    BANNER="Run ${BANNER_NAME} (v${VERSION})"
}

function check()
{
    local filename=$1

    # shellcheck disable=SC2310
    if is_included "${filename}"; then
        check_file "${filename}"
        return
    fi

    # shellcheck disable=SC2310
    if is_excluded "${filename}"; then
        skip "${filename}"
        return
    fi

    if [[ "${#include_list[@]}" -ne 0 ]]; then
        return
    fi
    check_file "${filename}"
}

function scan_files()
{
    while IFS= read -r filename; do
        if file -b "${filename}" | grep -qE "${FILE_TYPE_SEARCH_PATTERN}"; then
            check "${filename}"
        elif [[ "${filename}" =~ ${FILE_NAME_SEARCH_PATTERN} ]]; then
            check "${filename}"
        fi
    done < <(find "${SCAN_ROOT}" -type f -not -path "./.git/*" | sed 's|^./||' | sort -Vf || true)
}

function handle_parameters()
{
    stage "Parameters"

    if [[ -n "${REPORT_ONLY-}" ]] && [[ "${REPORT_ONLY}" = true ]]; then
        REPORT_ONLY=true
        echo " Report Only: ${cyan_text}true${reset}"
        parameters=true
    else
        REPORT_ONLY=false
    fi

    if [[ -n "${SHOW_ERRORS-}" ]] && [[ "${SHOW_ERRORS}" = false ]]; then
        SHOW_ERRORS=false
        echo " Show Errors: ${cyan_text}true${reset}"
        parameters=true
    else
        SHOW_ERRORS=true
    fi

    if [[ -n "${SHOW_SKIPPED-}" ]] && [[ "${SHOW_SKIPPED}" == true ]]; then
        SHOW_SKIPPED=true
        echo " Show Skipped: ${cyan_text}true${reset}"
        parameters=true
    else
        SHOW_SKIPPED=false
    fi

    if [[ -n "${INCLUDE_FILES-}" ]]; then
        IFS=',' read -r -a include_list <<< "${INCLUDE_FILES}"
        echo " Included Files: ${cyan_text}${INCLUDE_FILES}${reset}"
        parameters=true
    else
        include_list=()
    fi

    if [[ -n "${EXCLUDE_FILES-}" ]] && [[ "${#include_list[@]}" -eq 0 ]]; then
        IFS=',' read -r -a exclude_list <<< "${EXCLUDE_FILES}"
        echo " Excluded Files: ${cyan_text}${EXCLUDE_FILES}${reset}"
        parameters=true
    else
        exclude_list=()
    fi

    # shellcheck disable=SC2310
    if handle_non_standard_parameters; then
        parameters=true
    fi

    if [[ "${parameters}" != true ]]; then
        echo " No parameters given"
    fi
}

function handle_color_parameters()
{
    if [[ -n "${NO_COLOR-}" ]]; then
        if [[ "${NO_COLOR}" == true ]]; then
            NO_COLOR=true
        else
            NO_COLOR=false
        fi
    else
        NO_COLOR=false
    fi
}

function footer()
{
    stage 'Report'
    echo " ${bold_text}Total${reset}: ${file_count}, ${bold_text}${green_text}OK${reset}: ${ok_count}, ${bold_text}${red_text}Failed${reset}: ${fail_count}, ${bold_text}${yellow_text}Skipped${reset}: ${skip_count}"
    stage 'Complete'
}

function setup() {
    export TERM=xterm

    handle_color_parameters

    screen_width=0
    # shellcheck disable=SC2034
    bold_text=''
    # shellcheck disable=SC2034
    reset=''
    # shellcheck disable=SC2034
    black_text='' 
    # shellcheck disable=SC2034
    red_text=''
    # shellcheck disable=SC2034
    green_text=''
    # shellcheck disable=SC2034
    yellow_text=''
    # shellcheck disable=SC2034
    blue_text=''
    # shellcheck disable=SC2034
    magenta_text=''
    # shellcheck disable=SC2034
    cyan_text=''
    # shellcheck disable=SC2034
    white_text=''

    if [[ "${NO_COLOR}" == false ]]; then
        screen_width=$(tput cols)
        screen_width=$((screen_width - 2))

        # shellcheck disable=SC2034
        bold_text=$(tput bold)
        # shellcheck disable=SC2034
        reset=$(tput sgr0)
        # shellcheck disable=SC2034
        black_text=$(tput setaf 0)
        # shellcheck disable=SC2034
        red_text=$(tput setaf 1)
        # shellcheck disable=SC2034
        green_text=$(tput setaf 2)
        # shellcheck disable=SC2034
        yellow_text=$(tput setaf 3)
        # shellcheck disable=SC2034
        blue_text=$(tput setaf 4)
        # shellcheck disable=SC2034
        magenta_text=$(tput setaf 5)
        # shellcheck disable=SC2034
        cyan_text=$(tput setaf 6)
        # shellcheck disable=SC2034
        white_text=$(tput setaf 7)
    fi

    (( screen_width < 140 )) && screen_width=140
    file_count=0
    ok_count=0
    fail_count=0
    skip_count=0
    parameters=false
}

# -------------------------------------------------------------------------------- #
# Main                                                                             #
# -------------------------------------------------------------------------------- #

setup
handle_parameters
install_prerequisites
get_version_information
stage "${BANNER}"
scan_files
footer

[[ "${REPORT_ONLY}" == true ]] && EXIT_VALUE=0

exit "${EXIT_VALUE}"
