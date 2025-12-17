#!/bin/bash

readonly DOMAIN='https://raspberry-oregano-po8rcp4czwt22j7v.salad.cloud'
readonly ENDPOINT='ready'

curl --request  GET \
     --url     "${DOMAIN}/${ENDPOINT}"
