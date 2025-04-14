HOST_IMAGE = host_hfanzaou
ROUTER_IMAGE = routeur_hfanzaou

.PHONY: all build-host build-router clean

all: build-host build-router

build-host:
	docker build -f Dockerfile.host -t $(HOST_IMAGE) .

build-router:
	docker build -f Dockerfile.router -t $(ROUTER_IMAGE) .

clean:
	docker rmi -f $(HOST_IMAGE) $(ROUTER_IMAGE)
