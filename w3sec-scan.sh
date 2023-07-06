#!/usr/bin/env bash
#
# this script requires the w3sec CLI 
#
# recurse through directory structure and w3sec scan each 
# project for a given list of file types
#
# --mode= -> scanMode: one of [monitor, test]
# --type= -> projectType: one of [
#   javascript, python, java_maven, java_gradle, 
#   dotnet, ruby, golang, cocoapods, scala, php, all
# ]
# all is a special case that will iterate through each type
#
# --version= -> versionString: this can be used to enable tracking multiple
#   versions of an app.  This will be appended to all project names
#   and the project group.
# --args= -> extraArgs: this is w3sec CLI arguments which will be applied on 
#   every test/monitor command.  Don't use --project-name or --remote-repo-url
#   or --all-projects or --exclude
#
# --html= -> htmlReport: this indicates if w3sec-to-html should be used to 
#   generate local html reports.  Only works with 'test'.
#   Any --args will be discareded.
#   w3sec-to-html must be installed: https://github.com/w3sec/w3sec-to-html

htmlReport=0
rootDir="$(pwd)"

# logic taken from https://unix.stackexchange.com/a/580258
while [ $# -gt 0 ]; do
  case "$1" in
    --mode*)
      if [[ "$1" != *=* ]]; then shift; fi # Value is next arg if no `=`
      scanMode="${1#*=}"
      ;;
    --type*)
      if [[ "$1" != *=* ]]; then shift; fi
      projectType="${1#*=}"
      ;;
    --version*)
      if [[ "$1" != *=* ]]; then shift; fi
      versionString="${1#*=}"
      ;;
    --args*)
      if [[ "$1" != *=* ]]; then shift; fi
      extraArgs="${1#*=}"
      ;;
    --html*)
      if [[ "$1" != *=* ]]; then shift; fi
      htmlReport="${1#*=}"
      ;;
    --help|-h)
      echo ""
      echo "This is a prototype script to help use the w3sec CLI for monorepos."
      echo ""
      echo "--mode allows you to choose between test or monitor."
      echo "--type allows you to choose the language/package manager to look for:"
      echo "    w3sec-scan.sh --mode=test --type=java_gradle"
      echo "    w3sec-scan.sh --mode=monitor --type=all"
      echo ""
      echo "--version allows you to specify a version string if you want to track"
      echo "  multiple versions of the same monorepo:"
      echo "    w3sec-scan.sh --mode=test --type=java_gradle --version=1.2.3"
      echo ""
      echo "--html will do a test and provide local html reports."
      echo "  You must already have https://github.com/w3sec/w3sec-to-html available:"
      echo "    w3sec-scan.sh --html=1 --type=all"
      echo ""
      exit 0
      ;;
    *)
      >&2 echo "Error: Invalid argument"
      >&2 echo ""
      exit 1
      ;;
  esac
  shift
done


# set default exitCode for the entire set of scans
finalExitCode=0

# track the number of projects that resulted in a specific exit code
numExitCodes=(0 0 0)

# mapping of manifest files to project type
projectTypes_javascript="package-lock.json|yarn.lock"
projectTypes_python="requirements.txt|pyproject.toml"
projectTypes_java_maven="pom.xml"
projectTypes_java_gradle="build.gradle"
projectTypes_dotnet=".sln|.csproj|packages.config|project.json|paket.dependencies|project.assets.json"
projectTypes_ruby="Gemfile.lock"
projectTypes_golang="go.mod|vendor/vendor.json|Gopkg.lock"
projectTypes_cocoapods="Podfile"
projectTypes_scala="build.sbt"
projectTypes_php="composer.lock"

echo "scanMode set to: ${scanMode}"
echo "projectType set to: ${projectType}"
echo "using extraArgs: ${extraArgs}"

# w3sec monitor snapshots will be stored under this grouping
if [[ -n "$versionString" ]]; then
    projectGroup="$(basename `pwd`)-${versionString}"
else
    projectGroup=$(basename `pwd`)
fi

echo "projectGroup set to: ${projectGroup}"

w3sec_scan(){
    echo "testing manifest: ${1}"
    if [[ -n "$versionString" ]]; then
        projectName="${1:2}-${versionString}"
    else
        projectName="${1:2}"
    fi
    echo "project name: ${projectName}"
    if [[ "$htmlReport" == "1" ]]; then
        file_name="${rootDir}/$(echo $projectName | tr '/' '_').html"
        echo "${file_name}"
        w3sec test --file="${1}" --json | w3sec-to-html -o "${file_name}"
    else
        w3sec $scanMode --file="${1}" --project-name="${projectName}" --remote-repo-url="${projectGroup}" "$extraArgs"
    fi
    return $?
}

w3sec_gen_file_list(){
    file_array=($(echo $1 | tr '|' ' '))

    unset file_string

    for fname in ${file_array[@]}; do
        if [ -n "${file_string+set}" ]; then
            # we append a -o since this is the second file
            file_string+=" -o"
        fi
        file_string+=" -name *${fname}"
    done

    echo "$file_string"
}

w3sec_scan_by_type(){
    #echo "will look for files matching: ${!1}"
    #echo ""
    search_string=$(w3sec_gen_file_list ${!1})
    for manifest in $(find . -type f \( $search_string \) -not -path '*/\.*'); do 
        w3sec_scan $manifest; currentExitCode=$?
        if [[ $currentExitCode -gt $finalExitCode ]]; then
          finalExitCode=$currentExitCode
        fi
        ((numExitCodes[$currentExitCode]=numExitCodes[$currentExitCode]+1))
    done 
}

# unless projectType is 'all' process the specific types of projects
if [[ "${projectType}" != "all" ]]; then
    pt="projectTypes_${projectType}"
    w3sec_scan_by_type $pt
else # iterate through all known project types
    echo "will look for all known project types"
    echo ""
    # ${!projectTypes_*} expands to all our variables that start with projectType_
    for pt in ${!projectTypes_*}; do
        # ${pt#*_} chomps projectTypes_, giving us java, etc
        # ${!pt} takes the string "projectTypes_java" and uses it as a variable name instead
        echo "checking for ${pt#*_} manifests matching: ${!pt}"
        w3sec_scan_by_type $pt
    done
fi

echo ""
if [[ "$htmlReport" == "1" ]]; then
    echo "Completed generating reports"
    echo " - (2) Error: ${numExitCodes[2]}"
elif [[ "${scanMode}" == "test" ]]; then
    echo "Project Test Summary by Exit Code:"
    echo " - (0) No Vulns: ${numExitCodes[0]}"
    echo " - (1) Vulns: ${numExitCodes[1]}"
    echo " - (2) Scanning Error: ${numExitCodes[2]}"
elif [[ "${scanMode}" == "monitor" ]]; then
    echo "Project Monitor Summary by Exit Code:"
    echo " - (0) Success: ${numExitCodes[0]}"
    echo " - (1) Error: ${numExitCodes[1]}"
    echo " - (2) Scanning Error: ${numExitCodes[2]}"
fi

echo ""
echo "Exiting with code ${finalExitCode}"
exit $finalExitCode
