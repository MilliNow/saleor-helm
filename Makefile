
SALEOR_PROJECT ?= oliveland-platform-100
NAMESPACE ?= prod

clean:
	@rm -rf ~/Library/Caches/helm
	@rm -rf ~/Library/Preferences/helm
	@rm -rf ~/Library/helm

	@rm -rf ~/.helm/repository/cache/*
	@rm -rf ~/.helm/cache/archive/*

	@rm -rf ~/.cache/helm/

install:
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
		-f values/$(NAMESPACE).yaml \
		--debug

setup:
	@helm repo add saleor https://helm.theoliveland.com
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	@helm repo ls

update:
	@helm repo update
	@helm search repo saleor

releases:
	@echo -e '\nRELEASES'
	@helm list --namespace $(NAMESPACE)
	@echo -e '\nHISTORY'
	@helm history saleor --namespace $(NAMESPACE)

uninstall:
	@helm uninstall saleor --namespace $(NAMESPACE)
	@helm uninstall cert-manager --namespace $(NAMESPACE)
	@helm uninstall nginx --namespace $(NAMESPACE)

upgrade:
	@helm upgrade \
		saleor saleor/saleor \
		-f values/$(NAMESPACE).yaml \
		--debug \
		--namespace $(NAMESPACE)

template:
	@helm template \
		saleor saleor/saleor \
		-f values/$(NAMESPACE).yaml \
		--namespace $(NAMESPACE)

forward.saleor:
	$(eval SALEOR_POD_NAME := $(shell kubectl get pods --namespace $(NAMESPACE) -l "app.kubernetes.io/name=saleor,app.kubernetes.io/instance=saleor" -o jsonpath="{.items[0].metadata.name}"))
	$(eval SALEOR_SERVICE_PORT?=8000)

	@kubectl --namespace $(NAMESPACE) port-forward $(SALEOR_POD_NAME) $(SALEOR_SERVICE_PORT):$(SALEOR_SERVICE_PORT)

forward.dashboard:
	$(eval DASHBOARD_POD_NAME := $(shell kubectl get pods --namespace $(NAMESPACE) -l "app.kubernetes.io/name=dashboard,app.kubernetes.io/instance=saleor" -o jsonpath="{.items[0].metadata.name}"))
	$(eval SALEOR_DASHBOARD_SERVICE_PORT?=80)

	@kubectl --namespace $(NAMESPACE) port-forward $(DASHBOARD_POD_NAME) $(SALEOR_DASHBOARD_SERVICE_PORT):$(SALEOR_DASHBOARD_SERVICE_PORT)

forward.storefront:
	$(eval STOREFRONT_POD_NAME := $(shell kubectl get pods --namespace $(NAMESPACE) -l "app.kubernetes.io/name=storefront,app.kubernetes.io/instance=saleor" -o jsonpath="{.items[0].metadata.name}"))
	$(eval SALEOR_STOREFRONT_SERVICE_PORT?=80)

	@kubectl --namespace $(NAMESPACE) port-forward $(STOREFRONT_POD_NAME) $(SALEOR_STOREFRONT_SERVICE_PORT):$(SALEOR_STOREFRONT_SERVICE_PORT)

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
