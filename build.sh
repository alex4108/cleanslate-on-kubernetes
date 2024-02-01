#!/usr/bin/env bash

DOCKER_REPO="cleanslate"

## Set these values before running!

if [[ "${DOCKER_USER}" == "" ]]; then
    echo "Set env var DOCKER_USER to appropriate value"
    exit 1
fi

if [[ "${DOCKER_REPO}" == "" ]]; then
    echo "Set env var DOCKER_REPO to appropriate value"
    exit 1
fi

if [[ "${DOMAIN_NAME}" == "" ]]; then
    echo "Set env var DOMAIN_NAME to appropriate value"
    exit 1
fi

## Auto detect existing secrets

# shellcheck disable=SC2153
if [[ "$POSTGRES_PASSWORD" == "" ]]; then
    postgres_password_from_yml="$(yq < manifest.yml | jq -r 'select(.kind=="Secret" and .metadata.name=="calorie-tracker").data.POSTGRES_PASSWORD')"
    if [[ "${postgres_password_from_yml}" != "" ]]; then    
        POSTGRES_PASSWORD="$(echo -n "${postgres_password_from_yml}" | base64 -d)"
        POSTGRES_PASSWORD_B64="${postgres_password_from_yml}"
    else
        echo "Failed to find POSTGRES_PASSWORD from existing manifest.  Generating..."
        POSTGRES_PASSWORD="$(openssl rand -hex 32 | tr -dc '[:print:]')"
        POSTGRES_PASSWORD_B64="$(echo -n "${POSTGRES_PASSWORD}" | base64 | tr -d '\n')"
    fi
else
    POSTGRES_PASSWORD="$(echo -n "${POSTGRES_PASSWORD}" | base64 -d)"
    POSTGRES_PASSWORD_B64="${POSTGRES_PASSWORD}"
fi

# shellcheck disable=SC2086
pg_conn_string="$( echo -n postgres://postgres:${POSTGRES_PASSWORD}@postgres-service:5432/postgres | base64 | tr -d '\n')"

if [[ "${HASURA_GRAPHQL_ADMIN_SECRET}" == "" ]]; then
    hasura_graphql_admin_secret_from_yml="$(yq < manifest.yml | jq -r 'select(.kind=="Secret" and .metadata.name=="calorie-tracker").data.HASURA_GRAPHQL_ADMIN_SECRET')"
    if [[ "${hasura_graphql_admin_secret_from_yml}" != "" ]]; then
        HASURA_GRAPHQL_ADMIN_SECRET="${hasura_graphql_admin_secret_from_yml}"
    else
        echo "Failed to find HASURA_GRAPHQL_ADMIN_SECRET from existing manifest.  Generating..."
        HASURA_GRAPHQL_ADMIN_SECRET="$(openssl rand -hex 32 | tr -dc '[:print:]' | base64 | tr -d '\n')"
    fi
fi

if [[ "${HASURA_GRAPHQL_JWT_SECRET}" == "" ]]; then
    hasura_graphql_jwt_secret_from_yml="$(yq < manifest.yml | jq -r 'select(.kind=="Secret" and .metadata.name=="calorie-tracker").data.HASURA_GRAPHQL_JWT_SECRET')"
    if [[ "${hasura_graphql_jwt_secret_from_yml}" != "" ]]; then
        HASURA_GRAPHQL_JWT_SECRET="$(echo -n "${hasura_graphql_jwt_secret_from_yml}" | base64 -d)"
        HASURA_GRAPHQL_JWT_SECRET_B64="${hasura_graphql_jwt_secret_from_yml}"
    else
        echo "Failed to find HASURA_GRAPHQL_JWT_SECRET from existing manifest.  Generating..."
        hasura_graphql_jwt_secret='{ "type": "HS256", "key": "d374e7c8-912c-4871-bac2-7dde6afc2b55" }'
        # TODO What is this hardcoded value?
        # https://github.com/successible/cleanslate/issues/61
        HASURA_GRAPHQL_JWT_SECRET="${hasura_graphql_jwt_secret}"
        HASURA_GRAPHQL_JWT_SECRET_B64="$(echo -n "${HASURA_GRAPHQL_JWT_SECRET}" | base64 | tr -d '\n')"
    fi
else
    HASURA_GRAPHQL_JWT_SECRET="$(echo -n "${HASURA_GRAPHQL_JWT_SECRET}" | base64 -d)"
    HASURA_GRAPHQL_JWT_SECRET_B64="${HASURA_GRAPHQL_JWT_SECRET}"
fi

docker_config_json_from_yml="$(yq < manifest.yml | jq -r 'select(.kind=="Secret" and .metadata.name=="regcred").data.".dockerconfigjson"')"
if [[ "${docker_config_json_from_yml}" != "" ]]; then
    DOCKER_CONFIG_JSON="${docker_config_json_from_yml}"
else
    echo "Failed to find dockerconfigjson from existing manifest.  Generating..."
    docker_config_json="$(cat ~/.docker/config.json | base64 | tr -d '\n')"
    DOCKER_CONFIG_JSON="$(echo -n "${docker_config_json}")"
fi

set -euo pipefail

rm -rf cleanslate/
git clone https://github.com/successible/cleanslate.git
cd cleanslate

# TODO Stop checking out an old build...
# The last working build at time of writing is on this commit!?
# Check if we can destroy the following line...: https://github.com/successible/cleanslate/commits/main/

git checkout 52a46102570a19cd0378d8d014b17bb128776b5c

tag="$(git rev-parse HEAD)-$(date +%s)"

client_container_img="${DOCKER_USER}/${DOCKER_REPO}:client-${tag}"
docker build -t "${client_container_img}" \
    --build-arg NEXT_PUBLIC_FIREBASE_CONFIG='{}' \
    --build-arg NEXT_PUBLIC_HASURA_DOMAIN="${DOMAIN_NAME}" \
    --build-arg NEXT_PUBLIC_LOGIN_WITH_APPLE='yes' \
    --build-arg NEXT_PUBLIC_LOGIN_WITH_FACEBOOK='yes' \
    --build-arg NEXT_PUBLIC_LOGIN_WITH_GITHUB='no' \
    --build-arg NEXT_PUBLIC_LOGIN_WITH_GOOGLE='no' \
    --build-arg NEXT_PUBLIC_REACT_SENTRY_DSN='' \
    --build-arg NEXT_PUBLIC_USE_FIREBASE='no' \
    --build-arg NEXT_PUBLIC_VERSION=$(git rev-parse --short HEAD) \
    .

docker push "${client_container_img}"
echo "${client_container_img}"

pwd
cd ..

hasura_container_img="${DOCKER_USER}/${DOCKER_REPO}:hasura-${tag}"
docker build -t "${hasura_container_img}" -f Dockerfile.hasura .
docker push "${hasura_container_img}"
echo "${hasura_container_img}"

rm -rf manifest.yml
cp manifest.tpl manifest.yml

# TODO Fail if sed failed....

sed -i "s|postgres_password_placeholder|${POSTGRES_PASSWORD_B64}|g" manifest.yml
sed -i "s|hasura_graphql_admin_secret_placeholder|${HASURA_GRAPHQL_ADMIN_SECRET}|g" manifest.yml
sed -i "s|hasura_graphql_jwt_secret_placeholder|${HASURA_GRAPHQL_JWT_SECRET_B64}|g" manifest.yml
sed -i "s|client_container_img_placeholder|${client_container_img}|g" manifest.yml
sed -i "s|hasura_container_img_placeholder|${hasura_container_img}|g" manifest.yml
sed -i "s|version_placeholder|${tag}|g" manifest.yml
sed -i "s|domain_name_placeholder|${DOMAIN_NAME}|g" manifest.yml
sed -i "s|pg_conn_string_placeholder|${pg_conn_string}|g" manifest.yml
sed -i "s|dockerconfigjson_placeholder|${DOCKER_CONFIG_JSON}|g" manifest.yml