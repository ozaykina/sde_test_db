#!/bin/bash

docker run --name mydocker -e POSTGRES_PASSWORD="@sde_password012" -e POSTGRES_USER=test_sde -e POSTGRES_DB=demo -d -p 5432:5432 -v $(pwd)/sql:/var/lib/postgresql/sql postgres
sleep 5
docker exec -it mydocker psql -d demo -U test_sde -f /var/lib/postgresql/sql/init_db/demo.sql
