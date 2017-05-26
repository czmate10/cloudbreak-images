CBD_VERSION ?= $(shell curl -I https://github.com/sequenceiq/cloudbreak-deployer/releases/latest 2>&1 | sed -n "s/^Location:.*tag.v\([0-9\.]*\).*/\1/p")
CBD_VERSION_UNDERSCORE=$(shell echo $(CBD_VERSION) | tr -d .)

ENVS=CBD_VERSION=$(CBD_VERSION) CBD_VERSION_UNDERSCORE=$(CBD_VERSION_UNDERSCORE) TRACE=1
# it testing, atlas uploads should go to mocking artifact slush
PACKER_VARS=

PACKER_VARS=-var-file=vars-versions.json
ifdef DOCKER_VERSION
	PACKER_VARS+=-var yum_version_docker=$(DOCKER_VERSION)
endif

ifeq ($(MOCK),true)
	PACKER_OPTS+=$(PACKER_VARS) -var atlas_artifact=mock
else
	PACKER_OPTS+=$(PACKER_VARS)
endif

#deps:
	# go get github.com/bronze1man/yaml2json

build-amazon: generate-vars
	$(ENVS) ./scripts/packer.sh build -only=amazon $(PACKER_OPTS) packer.json

build-googlecompute: generate-vars
	$(ENVS) ./scripts/packer.sh build -only=googlecompute $(PACKER_OPTS) packer.json

build-azure: generate-vars
	$(ENVS) ./scripts/packer.sh build -only=azure-arm $(PACKER_OPTS) packer.json

create-managed-image:
	$(ENVS) ./scripts/create-managed-disk.sh

build-openstack: generate-vars
	$(ENVS) ./scripts/packer.sh build $(PACKER_OPTS) packer-openstack.json

generate-vars: docker-build
	docker run -v $(PWD):/work -w /work --entrypoint=bash images:build -c 'make generate-vars-local'

generate-vars-local:
	cat vars-versions.yml | yaml2json | jq . > vars-versions.json

docker-build:
	docker build -t images:build - < Dockerfile.build

check-docker-hub-build-status:
	$(ENVS) ./scripts/docker-hub-build-check.sh

build-in-docker:
	docker run -it \
		-v $(PWD):$(PWD) \
		-w $(PWD) \
		-e ATLAS_TOKEN=$(ATLAS_TOKEN) \
		-e MOCK=true \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v /usr/local/bin/docker:/usr/local/bin/docker \
		images:build make build-aws
