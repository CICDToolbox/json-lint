<!-- markdownlint-disable -->
<p align="center">
    <a href="https://github.com/CICDToolbox/">
        <img src="https://cdn.wolfsoftware.com/assets/images/github/organisations/cicdtoolbox/black-and-white-circle-256.png" alt="CICDToolbox logo" />
    </a>
    <br />
    <a href="https://github.com/CICDToolbox/json-lint/actions/workflows/cicd.yml">
        <img src="https://img.shields.io/github/actions/workflow/status/CICDToolbox/json-lint/cicd.yml?branch=master&label=build%20status&style=for-the-badge" alt="Github Build Status" />
    </a>
    <a href="https://github.com/CICDToolbox/json-lint/blob/master/LICENSE.md">
        <img src="https://img.shields.io/github/license/CICDToolbox/json-lint?color=blue&label=License&style=for-the-badge" alt="License">
    </a>
    <a href="https://github.com/CICDToolbox/json-lint">
        <img src="https://img.shields.io/github/created-at/CICDToolbox/json-lint?color=blue&label=Created&style=for-the-badge" alt="Created">
    </a>
    <br />
    <a href="https://github.com/CICDToolbox/json-lint/releases/latest">
        <img src="https://img.shields.io/github/v/release/CICDToolbox/json-lint?color=blue&label=Latest%20Release&style=for-the-badge" alt="Release">
    </a>
    <a href="https://github.com/CICDToolbox/json-lint/releases/latest">
        <img src="https://img.shields.io/github/release-date/CICDToolbox/json-lint?color=blue&label=Released&style=for-the-badge" alt="Released">
    </a>
    <a href="https://github.com/CICDToolbox/json-lint/releases/latest">
        <img src="https://img.shields.io/github/commits-since/CICDToolbox/json-lint/latest.svg?color=blue&style=for-the-badge" alt="Commits since release">
    </a>
    <br />
    <a href="https://github.com/CICDToolbox/json-lint/blob/master/.github/CODE_OF_CONDUCT.md">
        <img src="https://img.shields.io/badge/Code%20of%20Conduct-blue?style=for-the-badge" />
    </a>
    <a href="https://github.com/CICDToolbox/json-lint/blob/master/.github/CONTRIBUTING.md">
        <img src="https://img.shields.io/badge/Contributing-blue?style=for-the-badge" />
    </a>
    <a href="https://github.com/CICDToolbox/json-lint/blob/master/.github/SECURITY.md">
        <img src="https://img.shields.io/badge/Report%20Security%20Concern-blue?style=for-the-badge" />
    </a>
    <a href="https://github.com/CICDToolbox/json-lint/issues">
        <img src="https://img.shields.io/badge/Get%20Support-blue?style=for-the-badge" />
    </a>
</p>

## Overview

A tool to validate your JSON files using [jq](https://stedolan.github.io/jq/).

> Also see: [validate-json](https://github.com/DevelopersToolbox/validate-json) for our bash plugin to do the same thing.

This tool has been tested against the following:

1. GitHub Actions
2. Travis CI
3. CircleCI
4. BitBucket pipelines
5. Local command line

However due to the way that they are built they should work on most CICD platforms where you can run arbitrary scripts.

We provide a [script](https://github.com/CICDToolbox/get-all-tools) which pulls the latest copy of all the CICD tools and
places them in a local bin directory to allow them to be run any time locally for added validation.

## Basic Usage

```yml
on: [push, pull_request]

jobs:
  build:
    name: JSON lint
    runs-on: ubuntu-latest

    steps:
      - name: Checkout the Repository
        uses: actions/checkout@v4

      - name: Run JSON Lint
        run: bash <(curl -s https://raw.githubusercontent.com/CICDToolbox/json-lint/master/pipeline.sh)
```

### Configuration Options

The following environment variables can be set in order to customise the script.

| Name          | Default Value | Purpose                                                                                                         |
| :------------ | :-----------: | :-------------------------------------------------------------------------------------------------------------- |
| INCLUDE_FILES |     Unset     | A comma separated list of files to include for being scanned. You can also use `regex` to do pattern matching.  |
| EXCLUDE_FILES |     Unset     | A comma separated list of files to exclude from being scanned. You can also use `regex` to do pattern matching. |
| NO_COLOR      |     False     | Turn off the color in the output.                                                                               |
| REPORT_ONLY   |     False     | Generate the report but do not fail the build even if an error occurred.                                        |
| SHOW_ERRORS   |     True      | Show the actual errors instead of just which files had errors.                                                  |
| SHOW_SKIPPED  |     False     | Show which files are being skipped.                                                                             |

> If you set INCLUDE_FILES - it will skip ALL files that do not match, including anything in EXCLUDE_FILES.

You can use any combination of the above settings.

```yml
on: [push, pull_request]

jobs:
  build:
    name: JSON lint
    runs-on: ubuntu-latest

    steps:
      - name: Checkout the Repository
        uses: actions/checkout@v4

      - name: Run JSON Lint
        env:
          REPORT_ONLY: true
          SHOW_ERRORS: true
        run: bash <(curl -s https://raw.githubusercontent.com/CICDToolbox/json-lint/master/pipeline.sh)
```

## Example Output

This is an example of the output report generated by this tool, this is the actual output from the tool running against itself.

```
--------------------------------------------------------------------- Stage 1: Parameters --
 No parameters given
---------------------------------------------------------- Stage 2: Install Prerequisites --
 [  OK  ] jq is already installed
---------------------------------------------------------------- Stage 3: Run jq (v1.7.1) --
 [  OK  ] tests/data.json
------------------------------------------------------------------------- Stage 4: Report --
 Total: 1, OK: 1, Failed: 0, Skipped: 0
----------------------------------------------------------------------- Stage 5: Complete --
```

## File Identification

Target files are identified using the following code:

```shell
file -b "${filename}" | grep -qE '^JSON'

AND

[[ ${filename} =~ \.json$ ]]
```

<br />
<p align="right"><a href="https://wolfsoftware.com/"><img src="https://img.shields.io/badge/Created%20by%20Wolf%20on%20behalf%20of%20Wolf%20Software-blue?style=for-the-badge" /></a></p>
