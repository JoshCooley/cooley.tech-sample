#!/usr/bin/env bash

repo_name=$(basename "$(git rev-parse --show-toplevel)")
PROJECT_NAME=${PROJECT_NAME:=$repo_name}
PROJECT_TYPE=${PROJECT_TYPE:-python}
WITH_VENV=${WITH_VENV:-true}

linters=(flake8 pylint)
lint_project(){
  case $1 in
    # https://flake8.pycqa.org/en/latest/, https://www.pylint.org/
    flake8 | pylint )
      $1 .
      ;;
    * )
      printf '\nUsage: %s LINTER\nAvailable LINTERs: %s' \
        "${FUNCNAME[0]}" "${linters[*]}"
      return 1
      ;;
  esac
}

testers=(curl)
test_project(){
  case $1 in
    curl )
      PORT=12345 python -um "$PROJECT_NAME" & pythonpid=$!
      curl \
        --silent \
        --show-error \
        --connect-timeout 3 \
        --retry-connrefused \
        --retry 10 \
        --retry-delay 3 \
        http://localhost:12345/
      exit_code=$?
      kill "$pythonpid"
      return "$exit_code"
      ;;
    * )
      printf '\nUsage: %s TESTER\nAvailable TESTER: %s' \
        "${FUNCNAME[0]}" "${testers[*]}"
      return 1
      ;;
  esac
}

activate_venv(){
  if [[ -d venv ]]; then
    venv=venv
    echo 'Using existing venv directory ...'
  elif [[ -e venv || -L venv ]]; then
    echo "Cannot use venv dir './venv': File exists"
    exit 1
  else
    venv=$(mktemp -d)
    echo "Creating build venv $venv ..."
    python -m venv "$venv"
    echo "Linking ./venv to $venv ..."
    ln -s "$venv" venv
  fi
  echo 'Activating venv ...'
  . venv/bin/activate
}

if [[ $WITH_VENV == true ]]; then activate_venv; fi
echo
echo 'Installing dependencies ...'
pip install -r requirements.txt -r testing-requirements.txt
echo
for linter in "${linters[@]}"; do
  printf '%-50s' "Linting $PROJECT_TYPE with $linter ... "
  if lint=$(lint_project "$linter" 2>&1); then
    echo 'PASSED ✅'
  else
    echo 'FAILED ❌'
    echo "$lint"
    echo
    exit 1
  fi
done
for tester in "${testers[@]}"; do
  printf '%-50s' "Testing $PROJECT_TYPE with $tester ... "
  if test=$(test_project "$tester" 2>&1); then
    echo 'PASSED ✅'
  else
    echo 'FAILED ❌'
    echo "$test"
    echo
    exit 1
  fi
  echo Done.
  echo
done
if [[ $WITH_VENV == true && $venv != venv ]]; then rm -rf "${venv}"; fi