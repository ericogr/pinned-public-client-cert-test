package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"
	"net/http"
	"os"
)

// Função para carregar os certificados
func loadCertificates(certDir string) (tls.Certificate, *x509.CertPool, error) {
	// Caminhos dos certificados
	clientCertPath := certDir + "/client.crt"
	clientKeyPath := certDir + "/client.key"

	// Carregar o certificado do cliente
	clientCert, err := os.ReadFile(clientCertPath)
	if err != nil {
		return tls.Certificate{}, nil, fmt.Errorf("erro ao ler certificado do cliente: %v", err)
	}

	// Carregar a chave privada do cliente
	clientKey, err := os.ReadFile(clientKeyPath)
	if err != nil {
		return tls.Certificate{}, nil, fmt.Errorf("erro ao ler chave privada do cliente: %v", err)
	}

	// Criar a configuração do cliente com o certificado e chave privada
	clientCertTLS, err := tls.X509KeyPair(clientCert, clientKey)
	if err != nil {
		return tls.Certificate{}, nil, fmt.Errorf("erro ao carregar par de chaves do cliente: %v", err)
	}

	// Retornar o certificado do cliente e um pool vazio de CA (não vamos validar o servidor)
	return clientCertTLS, nil, nil
}

// Função para realizar a chamada HTTP com cliente certificado, ignorando o certificado do servidor
func makeHttpRequest(cert tls.Certificate, serverAddr string) (*http.Response, error) {
	// Configuração TLS para o cliente
	tlsConfig := &tls.Config{
		InsecureSkipVerify: false,                   // Ignorar a validação do certificado do servidor
		Certificates:       []tls.Certificate{cert}, // Enviar o certificado do cliente
	}

	// Criar um transporte HTTP com suporte a TLS
	transport := &http.Transport{
		TLSClientConfig: tlsConfig,
	}

	// Criar o cliente HTTP com o transporte configurado
	client := &http.Client{
		Transport: transport,
	}

	// Fazer a requisição HTTP para o servidor
	resp, err := client.Get(serverAddr)
	if err != nil {
		return nil, fmt.Errorf("erro ao fazer requisição HTTP: %v", err)
	}

	return resp, nil
}

func main() {
	// Definir o diretório dos certificados
	certsDir := "./certs"
	serverAddr := "https://www.ericogr.com.br:8443" // Endereço do servidor HTTP

	// Carregar certificados
	clientCertTLS, _, err := loadCertificates(certsDir)
	if err != nil {
		log.Fatalf("Erro ao carregar certificados: %v", err)
	}

	// Realizar requisição HTTP
	resp, err := makeHttpRequest(clientCertTLS, serverAddr)
	if err != nil {
		log.Fatalf("Erro ao fazer requisição HTTP: %v", err)
	}
	defer resp.Body.Close()

	// Exibir código de status da resposta HTTP
	fmt.Printf("Status da resposta: %s\n", resp.Status)
}
