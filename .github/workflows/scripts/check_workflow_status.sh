#!/bin/bash

source $( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/block_and_check_if_largest.sh

_tsv_to_markdown() {
  sed 's/^/| /; s/$/ |/; s/\t/ | /g' | awk 'NR==1 {print; print "| --- | --- | --- |"} NR!=1'
}

check_workflow_status() {
  if [[ $# -ne 4 ]]; then
    echo 'check_workflow_status $GH_TOKEN $REPOSITORY $GITHUB_SHA $WORKFLOW_RUN_ID ${DELAY:-60}'
    echo 'Example: check_workflow_status ${{ secrets.GITHUB_TOKEN }} ${{ github.repository }} ${{ github.sha }} ${{ github.run_id }} 60'
    echo 'Requires you to set the following outside this script: export THIS_WORKFLOW_PARENT_RUN_ID=${{ github.event.workflow_run.id }}'
    echo 'Prints all dependent workflow statuses of instances of the current workflow. Exits 1 if there are any failures'
    return 1
  fi
  GH_TOKEN=$1
  REPOSITORY=$2
  GITHUB_SHA=$3
  THIS_WORKFLOW_RUN_ID=$4

  workflows=$(_get_workflow_tree $GH_TOKEN $REPOSITORY $GITHUB_SHA $THIS_WORKFLOW_RUN_ID)
  table=$(
  echo -e "run_id\tparent_id\tparent_conclusion\troot_id\tworkflow_id\tworkflow_name"
  echo "$workflows" | while IFS=$'\t' read -r run_id root_id workflow_id workflow_name; do
    parent_id=$(_get_parent_run_id $run_id)
    parent_conclusion=$(_get_workflow_json $parent_id | jq -r '.conclusion')
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$run_id" "$parent_id" "$parent_conclusion" "$root_id" "$workflow_id" "$workflow_name"
  done
  )
  if [[ -z "${GITHUB_STEP_SUMMARY:-}" ]]; then
    echo "$table"
  else
    echo "$table" | _tsv_to_markdown | tee $GITHUB_STEP_SUMMARY
  fi
  
  # Overall success only if all parent runs were success
  overall_conclusion=$(echo "$table" | tail -n+2 | awk -F'\t' '{
      if ($3 != "success") {
          print "failure";
          exit;
      }
  } END {
      if (NR > 0) {
          print "success";
      }
  } ')
  echo "Overall conclusion: $overall_conclusion"
  if [[ $overall_conclusion == failure ]]; then
    exit 1
  fi
}