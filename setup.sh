#!/usr/bin/env bash

curl -X POST -H "Content-Type: application/json" -d '{"recipe_name":"Testing","recipe_type":"when","recipe_output":"trello","operator":">","comparison":"10","recipe_input":"event"}' http://localhost:5000/recipe