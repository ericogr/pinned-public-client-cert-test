# Diretório onde os certificados e chaves serão salvos
CERTS_DIR=certs

# Variáveis para a CA
CA_KEY=$(CERTS_DIR)/ca.key
CA_CERT=$(CERTS_DIR)/ca.crt
CA_SERIAL=$(CERTS_DIR)/ca.srl

# Variáveis para o servidor
SERVER_KEY=$(CERTS_DIR)/server.key
SERVER_CSR=$(CERTS_DIR)/server.csr
SERVER_CERT=$(CERTS_DIR)/server.crt

# Variáveis para o cliente
CLIENT_KEY=$(CERTS_DIR)/client.key
CLIENT_CSR=$(CERTS_DIR)/client.csr
CLIENT_CERT=$(CERTS_DIR)/client.crt

# Configurações gerais
DAYS=365
BITS=2048

# nginx
NGINX_IMAGE=nginx:stable-alpine3.20
NGINX_REMOTE_SERVER_CONTAINER_NAME=nginx_remote_server
NGINX_LOCAL_SERVER_CONTAINER_NAME=nginx_local_server

.PHONY: all clean ca server client

# Alvo principal: gera CA, servidor e cliente
all: ca server client docker-run

# Criar o diretório para certificados, se não existir
$(CERTS_DIR):
	@mkdir -p $(CERTS_DIR)

# Geração da CA
ca: $(CA_KEY) $(CA_CERT)

$(CA_KEY): | $(CERTS_DIR)
	@openssl genrsa -out $(CA_KEY) $(BITS)

$(CA_CERT): $(CA_KEY)
	@openssl req -x509 -new -nodes -key $(CA_KEY) -sha256 -days $(DAYS) -out $(CA_CERT) \
		-subj "/C=BR/ST=SaoPaulo/L=SaoPaulo/O=MyCompany/OU=CA/CN=MyRootCA"

# Geração do certificado do servidor
server: $(SERVER_KEY) $(SERVER_CERT)

$(SERVER_KEY): | $(CERTS_DIR)
	@openssl genrsa -out $(SERVER_KEY) $(BITS)

$(SERVER_CSR): $(SERVER_KEY)
	@openssl req -new -key $(SERVER_KEY) -out $(SERVER_CSR) \
		-subj "/C=BR/ST=SaoPaulo/L=SaoPaulo/O=MyCompany/OU=Server/CN=$(NGINX_REMOTE_SERVER_CONTAINER_NAME)"

$(SERVER_CERT): $(SERVER_CSR) $(CA_KEY) $(CA_CERT)
	@openssl x509 -req -in $(SERVER_CSR) -CA $(CA_CERT) -CAkey $(CA_KEY) -CAcreateserial \
		-out $(SERVER_CERT) -days $(DAYS) -sha256

# Geração do certificado do cliente
client: $(CLIENT_KEY) $(CLIENT_CERT)

$(CLIENT_KEY): | $(CERTS_DIR)
	@openssl genrsa -out $(CLIENT_KEY) $(BITS)

$(CLIENT_CSR): $(CLIENT_KEY)
	@openssl req -new -key $(CLIENT_KEY) -out $(CLIENT_CSR) \
		-subj "/C=BR/ST=SaoPaulo/L=SaoPaulo/O=MyCompany/OU=Client/CN=ClientApp"

$(CLIENT_CERT): $(CLIENT_CSR) $(CA_KEY) $(CA_CERT)
	@openssl x509 -req -in $(CLIENT_CSR) -CA $(CA_CERT) -CAkey $(CA_KEY) -CAcreateserial \
		-out $(CLIENT_CERT) -days $(DAYS) -sha256

# Limpar todos os arquivos gerados
clean: docker-clean
	@rm -rf $(CERTS_DIR)
	@docker network rm reserve-proxy-net

docker-run:
	@docker network create reserve-proxy-net || true
	@docker run -d --network reserve-proxy-net --name $(NGINX_LOCAL_SERVER_CONTAINER_NAME) -p 8000:8000 \
		-v $(PWD)/$(CERTS_DIR)/client.crt:/etc/nginx/ssl/client.crt:ro \
		-v $(PWD)/$(CERTS_DIR)/client.key:/etc/nginx/ssl/client.key:ro \
		-v $(PWD)/$(CERTS_DIR)/ca.crt:/etc/nginx/ssl/ca.crt:ro \
		-v $(PWD)/nginx_local_server/proxy.conf:/etc/nginx/conf.d/proxy.conf:ro \
		$(NGINX_IMAGE)
	@docker run -d --network reserve-proxy-net --name $(NGINX_REMOTE_SERVER_CONTAINER_NAME) -p 8443:8443 \
		-v $(PWD)/$(CERTS_DIR)/server.crt:/etc/nginx/ssl/server.crt:ro \
		-v $(PWD)/$(CERTS_DIR)/server.key:/etc/nginx/ssl/server.key:ro \
		-v $(PWD)/$(CERTS_DIR)/ca.crt:/etc/nginx/ssl/ca.crt:ro \
		-v $(PWD)/nginx_remote_server/proxy.conf:/etc/nginx/conf.d/proxy.conf:ro \
		$(NGINX_IMAGE)
	@docker run -d --network reserve-proxy-net --name backend -p 8080:80 \
		$(NGINX_IMAGE)
		
docker-stop:
	@docker stop $(NGINX_REMOTE_SERVER_CONTAINER_NAME) || docker rm $(NGINX_REMOTE_SERVER_CONTAINER_NAME)
	@docker stop $(NGINX_LOCAL_SERVER_CONTAINER_NAME) || docker rm $(NGINX_LOCAL_SERVER_CONTAINER_NAME)
	@docker stop backend || docker rm backend

docker-clean:
	@docker rm -f $(NGINX_REMOTE_SERVER_CONTAINER_NAME)
	@docker rm -f $(NGINX_LOCAL_SERVER_CONTAINER_NAME)
	@docker rm -f backend

test: test-without-certs test-with-certs

test-without-certs:
	@echo "Testing without certs"
	@echo "Should return 400"
	@echo --------------------------------------
	@curl -k https://localhost:8443


test-with-certs:
	@echo "Testing with certs"
	@echo "Should return 200"
	@echo --------------------------------------
	@curl -k --cert $(PWD)/$(CERTS_DIR)/client.crt --key $(PWD)/$(CERTS_DIR)/client.key https://localhost:8443
