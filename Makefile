NAMESPACE := minikube-practice
SECRET    := k8s/.env.secret

.DEFAULT_GOAL := help

.PHONY: help
help: ## Lista os comandos
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: start
start: ## Sobe o cluster local no minikube
	minikube start --cpus=2 --memory=4096

$(SECRET):
	cp k8s/.env.secret.example $(SECRET)
	@echo "Criei $(SECRET) a partir do exemplo. Troque a senha antes de usar fora do seu computador."

.PHONY: deploy
deploy: $(SECRET) ## Aplica os manifests e espera os pods ficarem prontos
	kubectl apply -k k8s
	kubectl -n $(NAMESPACE) rollout status deployment/mongo --timeout=180s
	kubectl -n $(NAMESPACE) rollout status deployment/webapp --timeout=180s

.PHONY: status
status: ## Mostra pods, services e o volume do Mongo
	kubectl -n $(NAMESPACE) get pods,svc,pvc -o wide

.PHONY: url
url: ## Abre a aplicação pelo NodePort do minikube
	minikube service webapp-service -n $(NAMESPACE) --url

.PHONY: smoke
smoke: ## Testa a aplicação de ponta a ponta via port-forward
	@kubectl -n $(NAMESPACE) port-forward svc/webapp-service 3000:3000 >/dev/null 2>&1 & \
	PF=$$!; trap "kill $$PF" EXIT; \
	curl -fsS --retry 10 --retry-connrefused --retry-delay 1 -o /dev/null \
	  -w "webapp respondeu HTTP %{http_code}\n" http://localhost:3000/

.PHONY: logs
logs: ## Acompanha os logs da aplicação
	kubectl -n $(NAMESPACE) logs -f deployment/webapp

.PHONY: validate
validate: ## Valida os manifests com kubeconform (sem cluster)
	kubectl kustomize k8s | kubeconform -strict -summary -

.PHONY: delete
delete: ## Remove tudo, inclusive os dados do Mongo
	kubectl delete namespace $(NAMESPACE) --ignore-not-found

.PHONY: stop
stop: ## Desliga o minikube
	minikube stop
