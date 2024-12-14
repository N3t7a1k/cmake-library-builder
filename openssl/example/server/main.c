#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/opensslv.h>
#include <openssl/x509.h>
#include <openssl/rsa.h>
#include <openssl/pem.h>
#include <openssl/bn.h>
#include <sys/socket.h>
#include <arpa/inet.h>

#define BUFFER_SIZE 2048

static EVP_PKEY* generate_key() {
    EVP_PKEY *pkey = NULL;
    
#if OPENSSL_VERSION_NUMBER >= 0x30000000L
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, NULL);
    if (ctx == NULL) return NULL;
    
    if (EVP_PKEY_keygen_init(ctx) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return NULL;
    }
    
    if (EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, 2048) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return NULL;
    }
    
    if (EVP_PKEY_keygen(ctx, &pkey) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return NULL;
    }
    
    EVP_PKEY_CTX_free(ctx);
    
#elif OPENSSL_VERSION_NUMBER >= 0x10100000L
    BIGNUM *bn = BN_new();
    RSA *rsa = RSA_new();
    
    if (!BN_set_word(bn, RSA_F4) || !RSA_generate_key_ex(rsa, 2048, bn, NULL)) {
        BN_free(bn);
        RSA_free(rsa);
        return NULL;
    }
    
    pkey = EVP_PKEY_new();
    if (pkey == NULL || !EVP_PKEY_assign_RSA(pkey, rsa)) {
        EVP_PKEY_free(pkey);
        RSA_free(rsa);
        pkey = NULL;
    }
    
    BN_free(bn);
    
#else
    RSA *rsa = RSA_generate_key(2048, RSA_F4, NULL, NULL);
    if (!rsa) return NULL;
    
    pkey = EVP_PKEY_new();
    if (pkey == NULL || !EVP_PKEY_assign_RSA(pkey, rsa)) {
        EVP_PKEY_free(pkey);
        RSA_free(rsa);
        pkey = NULL;
    }
#endif
    
    return pkey;
}

static SSL_CTX* create_context_with_cert() {
    SSL_CTX *ctx;
    EVP_PKEY *pkey = NULL;
    X509 *x509 = NULL;
    X509_NAME *name = NULL;
    
#if OPENSSL_VERSION_NUMBER < 0x10100000L
    ctx = SSL_CTX_new(SSLv23_server_method());
#else
    ctx = SSL_CTX_new(TLS_server_method());
#endif
    if (!ctx) {
        perror("SSL_CTX_new");
        return NULL;
    }
    SSL_CTX_set_options(ctx, SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3);
    
    pkey = generate_key();
    if (!pkey) {
        SSL_CTX_free(ctx);
        return NULL;
    }
    
    x509 = X509_new();
    if (!x509) {
        EVP_PKEY_free(pkey);
        SSL_CTX_free(ctx);
        return NULL;
    }
    
    X509_set_version(x509, 2);
    ASN1_INTEGER_set(X509_get_serialNumber(x509), 1);
    X509_gmtime_adj(X509_get_notBefore(x509), 0);
    X509_gmtime_adj(X509_get_notAfter(x509), 31536000L); 
    X509_set_pubkey(x509, pkey);
    
    name = X509_get_subject_name(x509);
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC, (unsigned char*)"TLS Echo Server", -1, -1, 0);
    X509_set_issuer_name(x509, name);
    
    X509_sign(x509, pkey, EVP_sha256());
    
    SSL_CTX_use_certificate(ctx, x509);
    SSL_CTX_use_PrivateKey(ctx, pkey);
    
    EVP_PKEY_free(pkey);
    X509_free(x509);
    
    return ctx;
}

static int create_socket(int port) {
    int sockfd;
    struct sockaddr_in addr;
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        perror("socket");
        return -1;
    }
    
    int enable = 1;
    if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int)) < 0) {
        perror("setsockopt");
        close(sockfd);
        return -1;
    }
    
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    if (bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sockfd);
        return -1;
    }
    
    if (listen(sockfd, 5) < 0) {
        perror("listen");
        close(sockfd);
        return -1;
    }
    
    return sockfd;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <port>\n", argv[0]);
        return 1;
    }
    
    int port = atoi(argv[1]);
    if (port <= 0 || port > 65535) {
        fprintf(stderr, "Invalid port number\n");
        return 1;
    }
    
    int ret = 1;
    int sockfd = -1;
    SSL_CTX *ctx = NULL;

#if OPENSSL_VERSION_NUMBER < 0x10100000L
    SSL_library_init();
    SSL_load_error_strings();
#else
    OPENSSL_init_ssl(OPENSSL_INIT_LOAD_SSL_STRINGS | OPENSSL_INIT_LOAD_CRYPTO_STRINGS, NULL);
#endif

    ctx = create_context_with_cert();
    if (!ctx) goto cleanup;
    
    sockfd = create_socket(port);
    if (sockfd < 0) goto cleanup;
    
    printf("Server listening on port %d\n", port);
    
    while(1) {
        struct sockaddr_in addr;
        unsigned int len = sizeof(addr);
        SSL *ssl;
        char buf[BUFFER_SIZE];
        int client;
        
        client = accept(sockfd, (struct sockaddr*)&addr, &len);
        if (client < 0) {
            perror("accept");
            continue;
        }
        
        ssl = SSL_new(ctx);
        SSL_set_fd(ssl, client);
        
        if (SSL_accept(ssl) <= 0) {
            ERR_print_errors_fp(stderr);
        } else {
            int bytes = SSL_read(ssl, buf, sizeof(buf));
            if (bytes > 0) {
                printf("Received: %.*s", bytes, buf);
                SSL_write(ssl, buf, bytes);
            }
        }
        
        SSL_free(ssl);
        close(client);
    }
    
    ret = 0;

cleanup:
    if (ret != 0) {
        ERR_print_errors_fp(stderr);
    }
    if (sockfd >= 0) close(sockfd);
    SSL_CTX_free(ctx);

#if OPENSSL_VERSION_NUMBER < 0x10100000L
    ERR_free_strings();
    EVP_cleanup();
#endif

    return ret;
}
