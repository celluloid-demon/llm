#!/bin/bash

readonly CN_GROUP='hello-world-1'
readonly ORGANIZATION='sixducks'
readonly PROJECT='default'

curl --request GET \
     --url    "https://api.salad.com/api/public/organizations/${ORGANIZATION}/projects/${PROJECT}/containers/${CN_GROUP}" \
     --header "Salad-Api-Key: ${API_KEY}" \
     --header "accept: application/json"
