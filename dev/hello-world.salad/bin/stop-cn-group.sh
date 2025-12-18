#!/bin/bash

readonly CN_GROUP='hello-world-1'
readonly ORGANIZATION='sixducks'
readonly PROJECT='default'
readonly ENDPOINT='stop'

curl --request POST \
     --url    "https://api.salad.com/api/public/organizations/${ORGANIZATION}/projects/${PROJECT}/containers/${CN_GROUP}/${ENDPOINT}" \
     --header "Salad-Api-Key: ${API_KEY}"
