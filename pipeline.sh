#!/usr/bin/env bash

# -------------------------------------------------------------------------------- #
# Description                                                                      #
# -------------------------------------------------------------------------------- #
# This script will locate and process all relevant files within the given git      #
# repository. Errors will be stored and a final exit status used to show if a      #
# failure occured during the processing.                                           #
# -------------------------------------------------------------------------------- #

# -------------------------------------------------------------------------------- #
# Configure the shell.                                                             #
# -------------------------------------------------------------------------------- #

set -Eeuo pipefail

# -------------------------------------------------------------------------------- #
# Global Variables                                                                 #
# -------------------------------------------------------------------------------- #
# TEST_COMMAND - The command to execute to perform the test.                       #
# FILE_TYPE_SEARCH_PATTERN - The pattern used to match file types.                 #
# FILE_NAME_SEARCH_PATTERN - The pattern used to match file names.                 #
# EXIT_VALUE - Used to store the script exit value - adjusted by the fail().       #
# -------------------------------------------------------------------------------- #

INSTALL_PACKAGE='jq'
TEST_COMMAND='jq'
FILE_TYPE_SEARCH_PATTERN='^JSON'
FILE_NAME_SEARCH_PATTERN='\.json$'
EXIT_VALUE=0

# -------------------------------------------------------------------------------- #
# Install                                                                          #
# -------------------------------------------------------------------------------- #
# Install the required tooling.                                                    #
# -------------------------------------------------------------------------------- #

function install_prerequisites
{
    sudo apt-get install "${INSTALL_PACKAGE}"
#    sudo apt-get -qq install "${INSTALL_PACKAGE}"
    TEST_COMMAND=$(which jq)
echo "1 = $TEST_COMMAND"

    VERSION=$("${INSTALL_PACKAGE}" --version | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')
    BANNER="Scanning all JSON with ${INSTALL_PACKAGE} (version: ${VERSION})"
}

# -------------------------------------------------------------------------------- #
# Validate JSON                                                                    #
# -------------------------------------------------------------------------------- #
# Use jq to check if a given string represents a valid JSON string.                #
# -------------------------------------------------------------------------------- #

function validate_json()
{
    json_string=$1

echo "2 = $TEST_COMMAND"

    if errors=$("${TEST_COMMAND}" . 2>&1 <<<"${json_string}"); then
        return 0
    fi
    echo "${errors}"
    return 1
}

# -------------------------------------------------------------------------------- #
# Validate JSON from file                                                          #
# -------------------------------------------------------------------------------- #
# A wrapper allowing the user to load a json string from a file and pass it to the #
# validate_json function.                                                          #
# -------------------------------------------------------------------------------- #

function validate_json_from_file()
{
    filename=${1:-}

    raw_json=$(<"${filename}")

    if errors=$(validate_json "${raw_json}"); then
        echo "JSON appears to be valid"
        return 0
    fi

    echo "${errors}"
    return 1
}

# -------------------------------------------------------------------------------- #
# Check                                                                            #
# -------------------------------------------------------------------------------- #
# Check a specific file.                                                           #
# -------------------------------------------------------------------------------- #

function check()
{
    local filename="$1"
    local errors

    file_count=$((file_count+1))

    if errors=$( validate_json_from_file "${filename}" 2>&1 ); then
        success "${filename}"
        ok_count=$((ok_count+1))
    else
        fail "${filename}" "${errors}"
        fail_count=$((fail_count+1))
    fi
}

# -------------------------------------------------------------------------------- #
# Scan Files                                                                       #
# -------------------------------------------------------------------------------- #
# Locate all of the relevant files within the repo and process compatible ones.    #
# -------------------------------------------------------------------------------- #

function scan_files()
{
    while IFS= read -r filename
    do
        if file -b "${filename}" | grep -qE "${FILE_TYPE_SEARCH_PATTERN}"; then
            check "${filename}"
        elif [[ "${filename}" =~ ${FILE_NAME_SEARCH_PATTERN} ]]; then
            check "${filename}"
        fi
    done < <(git ls-files | sort -zVd)
}

# -------------------------------------------------------------------------------- #
# Handle Parameters                                                                #
# -------------------------------------------------------------------------------- #
# Handle any parameters from the pipeline.                                         #
# -------------------------------------------------------------------------------- #

function handle_parameters
{
    if [[ -n "${SHOW_ERRORS-}" ]]; then
        if [[ "${SHOW_ERRORS}" != true ]]; then
            SHOW_ERRORS=false
        fi
    else
        SHOW_ERRORS=false
    fi

    if [[ -n "${REPORT_ONLY-}" ]]; then
        if [[ "${REPORT_ONLY}" != true ]]; then
            REPORT_ONLY=false
        fi
    else
        REPORT_ONLY=false
    fi

    if [[ "${REPORT_ONLY}" == true ]]; then
        center_text "WARNING: REPORT ONLY MODE"
        draw_line
    fi
}


# -------------------------------------------------------------------------------- #
# Success                                                                          #
# -------------------------------------------------------------------------------- #
# Show the user that the processing of a specific file was successful.             #
# -------------------------------------------------------------------------------- #

function success()
{
    local message="${1:-}"

    if [[ -n "${message}" ]]; then
        printf ' [  %s%sOK%s  ] Processing successful for %s\n' "${bold}" "${success}" "${normal}" "${message}"
    fi
}

# -------------------------------------------------------------------------------- #
# Fail                                                                             #
# -------------------------------------------------------------------------------- #
# Show the user that the processing of a specific file failed and adjust the       #
# EXIT_VALUE to record this.                                                       #
# -------------------------------------------------------------------------------- #

function fail()
{
    local message="${1:-}"
    local errors="${2:-}"

    if [[ -n "${message}" ]]; then
        printf ' [ %s%sFAIL%s ] Processing failed for %s\n' "${bold}" "${error}" "${normal}" "${message}"
    fi

    if [[ "${SHOW_ERRORS}" == true ]]; then
        if [[ -n "${errors}" ]]; then
            echo "${errors}"
        fi
    fi

    EXIT_VALUE=1
}

# -------------------------------------------------------------------------------- #
# Skip                                                                             #
# -------------------------------------------------------------------------------- #
# Show the user that the processing of a specific file was skipped.                #
# -------------------------------------------------------------------------------- #

function skip()
{
    local message="${1:-}"

    file_count=$((file_count+1))
    if [[ -n "${message}" ]]; then
        printf ' [ %s%sSkip%s ] Skipping %s\n' "${bold}" "${skip}" "${normal}" "${message}"
    fi
}

# -------------------------------------------------------------------------------- #
# Center Text                                                                      #
# -------------------------------------------------------------------------------- #
# Center the given string on the screen. Part of the report generation.            #
# -------------------------------------------------------------------------------- #

function center_text()
{
    local message="${1:-}"

    textsize=${#message}
    span=$(((screen_width + textsize) / 2))

    printf '%*s\n' "${span}" "${message}"
}

# -------------------------------------------------------------------------------- #
# Draw Line                                                                        #
# -------------------------------------------------------------------------------- #
# Draw a line on the screen. Part of the report generation.                        #
# -------------------------------------------------------------------------------- #

function draw_line
{
    printf '%*s\n' "${screen_width}" '' | tr ' ' -
}

# -------------------------------------------------------------------------------- #
# Header                                                                           #
# -------------------------------------------------------------------------------- #
# Draw the report header on the screen. Part of the report generation.             #
# -------------------------------------------------------------------------------- #

function header
{
    draw_line
    center_text "${BANNER}"
    draw_line
}

# -------------------------------------------------------------------------------- #
# Footer                                                                           #
# -------------------------------------------------------------------------------- #
# Draw the report footer on the screen. Part of the report generation.             #
# -------------------------------------------------------------------------------- #

function footer
{
    draw_line
    center_text "Total: ${file_count}, OK: ${ok_count}, Failed: ${fail_count}, Skipped: $skip_count"
    draw_line
}

# -------------------------------------------------------------------------------- #
# Setup                                                                            #
# -------------------------------------------------------------------------------- #
# Handle any custom setup that is required.                                        #
# -------------------------------------------------------------------------------- #

function setup
{
    export TERM=xterm

    screen_width=$(tput cols)
    bold="$(tput bold)"
    normal="$(tput sgr0)"
    error="$(tput setaf 1)"
    success="$(tput setaf 2)"
    skip="$(tput setaf 6)"

    file_count=0
    ok_count=0
    fail_count=0
    skip_count=0
}

# -------------------------------------------------------------------------------- #
# Main()                                                                           #
# -------------------------------------------------------------------------------- #
# This is the actual 'script' and the functions/sub routines are called in order.  #
# -------------------------------------------------------------------------------- #

setup
install_prerequisites
header
handle_parameters
scan_files
footer

if [[ "${REPORT_ONLY}" == true ]]; then
    EXIT_VALUE=0
fi

exit $EXIT_VALUE

# -------------------------------------------------------------------------------- #
# End of Script                                                                    #
# -------------------------------------------------------------------------------- #
# This is the end - nothing more to see here.                                      #
# -------------------------------------------------------------------------------- #
