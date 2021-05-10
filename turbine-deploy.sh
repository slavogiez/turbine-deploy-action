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

JOB_ID=""

if [[ -z "$ENVIRONMENT_NAME" ]]
then
	# no env given, job image_post_build
	JOB_ID=$(curl -sS -X POST \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer $TEAM_TOKEN" \
	  --data '{
	  "type": "image_post_build",
	  "parameters": {
	    "service": "'$COMPONENT_NAME'",
	    "version": "'$VERSION_TO_DEPLOY'"
	  },
	  "state": "PENDING"
	}' $TURBINE_JOBS_URL | jq -r '.id')

else
	# env given, job image_deploy
	JOB_ID=$(curl -sS -X POST \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer $TEAM_TOKEN" \
	  --data '{
	  "type": "image_deploy",
	  "parameters": {
	    "environment": "'$ENVIRONMENT_NAME'",
	    "service": "'$COMPONENT_NAME'",
	    "version": "'$VERSION_TO_DEPLOY'"
	  },
	  "state": "PENDING"
	}' $TURBINE_JOBS_URL | jq -r '.id')

fi

if [[ -z "$JOB_ID" ]]
then
	echo "Got empty job id"
	exit 1
fi

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
	  break
	fi

done
