#!/bin/bash

echo "Start of turbine-deploy-action"

TURBINE_URL=https://turbine.adeo.cloud
TURBINE_JOBS_URL=$TURBINE_URL'/api/jobs-manager/jobs?schedule=true'

ENVIRONMENT_NAME=$TURBINE_ENVIRONMENT
COMPONENT_NAME=$(echo "$TURBINE_COMPONENT" | sed -r 's|^[^/]*/||') # the sed remove adeo/ if present
VERSION_TO_DEPLOY=$TURBINE_VERSION
TEAM_TOKEN=$TURBINE_TOKEN

slugify() {
	echo $1 | sed -r '
s|^refs/heads/||
s/[^a-zA-Z0-9]+/-/g
s/^-+//g
s/-+$//g' | tr A-Z a-z
}

if [[ "$VERSION_TO_DEPLOY" = refs/heads/* ]]
then
	# branch name, slugify it
	VERSION_TO_DEPLOY=$(slugify $VERSION_TO_DEPLOY)
fi


COMPONENT_NAME=$(slugify $COMPONENT_NAME)


if [[ -z "$TEAM_TOKEN" ]]
then
	echo "Missing turbine token parameter: token"
	exit 1
fi

if [[ -z "$COMPONENT_NAME" ]]
then
	echo "Missing component name parameter: component"
	exit 1
fi

if [[ -z "$VERSION_TO_DEPLOY" ]]
then
	echo "Missing version parameter: version"
	exit 1
fi

JOB_RESPONSE=""

if [[ -z "$ENVIRONMENT_NAME" ]]
then
	# no env given, job image_post_build
  echo "Starting job image_post_build with parameters
    component: '$COMPONENT_NAME',
    version: '$VERSION_TO_DEPLOY'"

	JOB_RESPONSE=$(curl -sS -X POST \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer $TEAM_TOKEN" \
	  --data '{
	  "type": "image_post_build",
	  "parameters": {
	    "component": "'$COMPONENT_NAME'",
	    "version": "'$VERSION_TO_DEPLOY'"
	  },
	  "state": "PENDING"
	}' $TURBINE_JOBS_URL)

else
	# env given, job image_deploy
  echo "Starting job image_deploy with parameters
    environment: '$ENVIRONMENT_NAME',
    component: '$COMPONENT_NAME',
    version: '$VERSION_TO_DEPLOY'"

	JOB_RESPONSE=$(curl -sS -X POST \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer $TEAM_TOKEN" \
	  --data '{
	  "type": "image_deploy",
	  "parameters": {
	    "environment": "'$ENVIRONMENT_NAME'",
	    "component": "'$COMPONENT_NAME'",
	    "version": "'$VERSION_TO_DEPLOY'"
	  },
	  "state": "PENDING"
	}' $TURBINE_JOBS_URL)

fi

JOB_ID=$(echo $JOB_RESPONSE | jq -r '.id')


if [[ -z "$JOB_ID" ]]
then
	echo "Got empty job id"
	echo $JOB_RESPONSE
	exit 1
fi

if [[ "$JOB_ID" = "null" ]]
then
	echo "Got empty job id"
	echo $JOB_RESPONSE
	exit 1
fi

echo "Got job id: $JOB_ID"
echo "You can see full job at $TURBINE_URL/jobs/$JOB_ID"

for i in $(seq 1 100); do

	echo "waiting for job to end..."
	sleep 3
	JOB="$(curl -sS -X GET \
	  -H "Authorization: Bearer $TEAM_TOKEN" \
	  $TURBINE_URL'/api/jobs-manager/jobs/'$JOB_ID)"

	JOB_STATE=$(echo "$JOB" | jq -r '.state')
	if [ "$JOB_STATE" = 'FAILURE' ] || [ "$JOB_STATE" = 'SUCCESS' ] || [ "$JOB_STATE" = 'CANCELLED' ]
	then
	  echo $JOB | jq -r '.logs'
    echo "Job ended in state: $JOB_STATE"

	  if [ "$JOB_STATE" != 'SUCCESS' ]
	  then
	  	exit 1
	  fi

	  exit 0
	fi

done

echo "Time out while waiting for job to end"
