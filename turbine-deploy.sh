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

if [[ -z "$ENVIRONMENT_NAME" ]]
then
	# no env given, job image_post_build
	curl -sS -X POST \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer $TEAM_TOKEN" \
	  --data '{
	  "type": "image_post_build",
	  "parameters": {
	    "service": "'$COMPONENT_NAME'",
	    "version": "'$VERSION_TO_DEPLOY'"
	  },
	  "state": "PENDING"
	}' $TURBINE_JOBS_URL

else
	# env given, job image_deploy
	curl -sS -X POST \
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
	}' $TURBINE_JOBS_URL

fi

