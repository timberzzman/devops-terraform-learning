#!/bin/bash

docker run -d --name app -e DATABASE_URI="$(scw-userdata DATABASE_URI)" -p 80:8080 --restart=always rg.fr-par.scw.cloud/efrei-devops/app:latest
