
CLUST ?= saleor-platform
CLUST_REG ?= us-central1
CLUST_ZONE ?= $(CLUST_REG)-a
SALEOR_PROJECT ?= oliveland
MACHINE_TYPE ?= n1-standard-2
ENV ?= prod
NAMESPACE ?= $(CLUST)-$(ENV)
SECRET_NAME ?= $(NAMESPACE)-secret

namespace:
	@echo "Creating Kubernetes namespace: $(NAMESPACE)"
	@kubectl create namespace $(NAMESPACE)

cluster.config:
	@echo "Fetching cluster '$(CLUST)' credentials from GCloud..."
	@gcloud container clusters get-credentials $(CLUST) \
		--project $(SALEOR_PROJECT)\
		--region $(CLUST_ZONE)

cluster.destroy:
	@echo "Destroying cluster '$(CLUST)' from GCloud..."
	@gcloud container clusters delete $(CLUST) \
		--project $(SALEOR_PROJECT)\
		--region $(CLUST_ZONE)

secret:
	@echo "Creating secret '$(SECRET_NAME)'..."
	@kubectl create secret generic $(SECRET_NAME) \
		--from-literal=secret=$(SECRET) \
		--namespace $(NAMESPACE)

cluster:
	@echo "Creating cluster '$(CLUST)' in '$(SALEOR_PROJECT)/$(CLUST_ZONE)'"
	@gcloud container clusters create $(CLUST) \
		--release-channel regular \
		--machine-type=$(MACHINE_TYPE) \
		--region $(CLUST_ZONE) \
		--num-nodes 1 \
		--project $(SALEOR_PROJECT)\
		--node-locations $(CLUST_ZONE)
	@make namespace
	@make cluster.config
	@make secret

cluster.status:
	@echo "\nDEPLOYMENTS"
	@kubectl get deployments --namespace $(NAMESPACE)

	@echo "\nREPLICA SETS"
	@kubectl get replicasets --namespace $(NAMESPACE)

	@echo "\nPODS"
	@kubectl get pods --namespace $(NAMESPACE)

	@echo "\nSERVICES"
	@kubectl get svc --namespace $(NAMESPACE)

	@echo "\nINGRESS"
	@kubectl get ingress --namespace $(NAMESPACE)

	@echo "\nIP ADDRESSES"
	@gcloud compute addresses list --project $(SALEOR_PROJECT)

	@echo "\nCertificates"
	@kubectl get certificate --namespace $(NAMESPACE)

clean:
	@rm -rf ~/Library/Caches/helm
	@rm -rf ~/Library/Preferences/helm
	@rm -rf ~/Library/helm

	@rm -rf ~/.helm/repository/cache/*
	@rm -rf ~/.helm/cache/archive/*

	@rm -rf ~/.cache/helm/

helm.install:
	$(eval IP_ADDRESS := $(shell gcloud compute addresses list --project=$(SALEOR_PROJECT) --format="value(address)" --filter="name:nginx-$(NAMESPACE)"))
	@helm install \
		nginx ingress-nginx/ingress-nginx \
	    --set controller.service.loadBalancerIP="$(IP_ADDRESS)" \
		--namespace $(NAMESPACE)

	@helm install \
		cert-manager jetstack/cert-manager \
		--namespace $(NAMESPACE) \
		--set installCRDs=true

	@sleep 60
	@helm install \
		--namespace $(NAMESPACE) \
		saleor saleor/saleor \
		--set secretKey.name=$(SECRET_NAME) \
		--debug

helm.setup:
	@helm repo add saleor https://helm.theoliveland.com
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	@helm repo ls

helm.update:
	@helm repo update
	@helm search repo saleor

helm.releases:
	@echo -e '\nRELEASES'
	@helm list --namespace $(NAMESPACE)
	@echo -e '\nHISTORY'
	@helm history saleor --namespace $(NAMESPACE)

helm.uninstall:
	@helm uninstall saleor --namespace $(NAMESPACE)
	@helm uninstall cert-manager --namespace $(NAMESPACE)
	@helm uninstall nginx --namespace $(NAMESPACE)

deploy: helm.setup helm.update helm.install
	echo "Helm deployed successfully!"

upgrade: helm.update
	@helm upgrade \
		saleor saleor/saleor \
		--set secretKey.name=$(SECRET_NAME) \
		--debug \
		--namespace $(NAMESPACE)

forward.saleor:
	$(eval SALEOR_POD_NAME := $(shell kubectl get pods --namespace $(NAMESPACE) -l "app.kubernetes.io/name=saleor,app.kubernetes.io/instance=saleor" -o jsonpath="{.items[0].metadata.name}"))
	$(eval SALEOR_SERVICE_PORT?=8000)

	@kubectl --namespace $(NAMESPACE) port-forward $(SALEOR_POD_NAME) $(SALEOR_SERVICE_PORT):$(SALEOR_SERVICE_PORT)

forward.dashboard:
	$(eval DASHBOARD_POD_NAME := $(shell kubectl get pods --namespace $(NAMESPACE) -l "app.kubernetes.io/name=dashboard,app.kubernetes.io/instance=saleor" -o jsonpath="{.items[0].metadata.name}"))
	$(eval SALEOR_DASHBOARD_SERVICE_PORT?=8080)

	@kubectl --namespace $(NAMESPACE) port-forward $(DASHBOARD_POD_NAME) $(SALEOR_DASHBOARD_SERVICE_PORT):$(SALEOR_DASHBOARD_SERVICE_PORT)

forward.storefront:
	$(eval STOREFRONT_POD_NAME := $(shell kubectl get pods --namespace $(NAMESPACE) -l "app.kubernetes.io/name=storefront,app.kubernetes.io/instance=saleor" -o jsonpath="{.items[0].metadata.name}"))
	$(eval SALEOR_STOREFRONT_SERVICE_PORT?=8080)

	@kubectl --namespace $(NAMESPACE) port-forward $(STOREFRONT_POD_NAME) $(SALEOR_STOREFRONT_SERVICE_PORT):$(SALEOR_STOREFRONT_SERVICE_PORT)

bash:
	@kubectl exec --stdin --tty $(POD_NAME) --namespace $(NAMESPACE) -- /bin/sh

chart.package:
	@echo "Make sure to update the chart version in the repo"
	@rm -rf .deploy
	@helm dependency update charts/storefront
	@helm dependency update charts/dashboard
	@helm dependency update charts/saleor
	@helm package charts/storefront --destination .deploy
	@helm package charts/dashboard --destination .deploy
	@helm package charts/saleor --destination .deploy

chart.release:
	@cr upload --config config.yaml

chart.index: chart.package chart.release
	@cr index --config config.yaml
	@git add index.yaml charts/saleor/Chart.lock
	@git commit -m "Update index.yaml" -- index.yaml charts/saleor/Chart.lock
	@git push
	@git add .
	@echo "Commit and push changes"

events:
	@kubectl -n $(NAMESPACE) get events --sort-by='{.lastTimestamp}'

ip.create:
	@gcloud compute addresses create nginx-$(NAMESPACE) \
		--region $(CLUST_REG)\
		--project $(SALEOR_PROJECT)
