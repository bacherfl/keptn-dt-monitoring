#!/bin/bash

source ./utils.sh

function evaluate_service() {
  evaluated_project=$1
  evaluated_service=$2
  nr_projects=$3
  nr_services=$4
  nr_evaluations=$5
  nr_invalidations=$6

  cat << EOF > ./tmp-trigger-evaluation.json
  {
    "type": "sh.keptn.event.qg.evaluation.triggered",
    "specversion": "1.0",
    "source": "travis-ci",
    "contenttype": "application/json",
    "data": {
      "project": "$evaluated_project",
      "stage": "qg",
      "service": "$evaluated_service",
      "deployment": {
        "deploymentURIsLocal": ["$evaluated_service:8080"]
      }
    }
  }
EOF

  cat tmp-trigger-evaluation.json

  keptn_context_id=$(send_event_json ./tmp-trigger-evaluation.json)
  rm tmp-trigger-evaluation.json

  # try to fetch a evaluation.finished event
  echo "Getting evaluation.finished event with context-id: ${keptn_context_id}"
  resp=$(get_event_with_retry sh.keptn.event.evaluation.finished ${keptn_context_id} ${SELF_MONITORING_PROJECT})
  echo $resp
}


evaluation_finished=$(evaluate_service keptn mongodb-datastore "0" "0" "0" "0")

