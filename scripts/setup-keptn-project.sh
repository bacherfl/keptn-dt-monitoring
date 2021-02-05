#!/bin/bash

source utils.sh

SELF_MONITORING_PROJECT=${SELF_MONITORING_PROJECT:-keptn}
KEPTN_NAMESPACE=${KEPTN_NAMESPACE:-keptn}

DYNATRACE_SLI_SERVICE_VERSION=${DYNATRACE_SLI_SERVICE_VERSION:-master}
DYNATRACE_SERVICE_VERSION=${DYNATRACE_SERVICE_VERSION:-master}

if [[ $DT_TENANT == "" ]]; then
  echo "No DT Tenant env var provided. Exiting."
  exit 1
fi

if [[ $DT_API_TOKEN == "" ]]; then
  echo "No DZ API Token env var provided. Exiting."
  exit 1
fi


# get keptn API details
if [[ "$PLATFORM" == "openshift" ]]; then
  KEPTN_ENDPOINT=http://api.${KEPTN_NAMESPACE}.127.0.0.1.nip.io/api
else
  if [[ "$KEPTN_SERVICE_TYPE" == "NodePort" ]]; then
    API_PORT=$(kubectl get svc api-gateway-nginx -n ${KEPTN_NAMESPACE} -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
    INTERNAL_NODE_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }')
    KEPTN_ENDPOINT="http://${INTERNAL_NODE_IP}:${API_PORT}"/api
  else
    KEPTN_ENDPOINT=http://$(kubectl -n ${KEPTN_NAMESPACE} get service api-gateway-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/api
  fi
fi

KEPTN_API_TOKEN=$(kubectl get secret keptn-api-token -n ${KEPTN_NAMESPACE} -ojsonpath={.data.keptn-api-token} | base64 --decode)


# create secret containing dynatrace credentials
kubectl -n ${KEPTN_NAMESPACE} create secret generic dynatrace-credentials-${SELF_MONITORING_PROJECT} --from-literal="DT_TENANT=$QG_INTEGRATION_TEST_DT_TENANT" --from-literal="DT_API_TOKEN=$QG_INTEGRATION_TEST_DT_API_TOKEN"

echo "Install dynatrace-sli-service from: ${DYNATRACE_SLI_SERVICE_VERSION}"
kubectl apply -f https://raw.githubusercontent.com/keptn-contrib/dynatrace-sli-service/${DYNATRACE_SLI_SERVICE_VERSION}/deploy/service.yaml -n ${KEPTN_NAMESPACE}
kubectl -n ${KEPTN_NAMESPACE} set image deployment/dynatrace-sli-service dynatrace-sli-service=keptncontrib/dynatrace-sli-service:0.6.0-master

echo "Install dynatrace-service from: ${DYNATRACE_SERVICE_VERSION}"
kubectl apply -f https://raw.githubusercontent.com/keptn-contrib/dynatrace-service/${DYNATRACE_SERVICE_VERSION}/deploy/service.yaml -n ${KEPTN_NAMESPACE}
kubectl -n ${KEPTN_NAMESPACE} set image deployment/dynatrace-service dynatrace-service=keptncontrib/dynatrace-service:0.10.2-dev

wait_for_deployment_in_namespace "dynatrace-sli-service" ${KEPTN_NAMESPACE}
wait_for_deployment_in_namespace "dynatrace-service" ${KEPTN_NAMESPACE}

keptn configure monitoring --project=${SELF_MONITORING_PROJECT} dynatrace

# create the project

keptn create project $SELF_MONITORING_PROJECT --shipyard=./assets/shipyard.yaml

keptn add-resource --project=$SELF_MONITORING_PROJECT --resource=./assets/dynatrace_sli.yaml --resourceUri=dynatrace/sli.yaml

# create services

SERVICES=("bridge" "configuration-service" "mongodb-datastore" "gatekeeper-service" "remediation-service" "lighthouse-service" "statistics-service" "gatekeeper-service" "dynatrace-sli-service" "jmeter-service" "api-service" "api-gateway-nginx")

for SERVICE in "${SERVICES[@]}"
do
    keptn create service $SERVICE --project=$SELF_MONITORING_PROJECT
done

for SERVICE in "${SERVICES[@]}"
do
    keptn add-resource --project=$SELF_MONITORING_PROJECT --service=$SERVICE --stage=qg --resource=./assets/slo.yaml --resourceUri=slo.yaml
done


# upload .jmx script for the mongodb-datastore
keptn add-resource --project=$SELF_MONITORING_PROJECT --service=mongodb-datastore --stage=qg --resource=./assets/mongodb-performance.jmx --resourceUri=jmeter/load.jmx




