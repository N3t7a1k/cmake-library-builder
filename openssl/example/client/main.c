#include <stdio.h>
#include <string.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/opensslv.h>

#define VERIFY_CERTIFICATE 0
#define BUFFER_SIZE 2048

int main(int argc, char *argv[]) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <hostname> <port> <message>\n", argv[0]);
        return 1;
    }

    int ret = 1;
    BIO *bio = NULL;
    SSL_CTX *ctx = NULL;
    SSL *ssl = NULL;
    char buf[BUFFER_SIZE];

#if OPENSSL_VERSION_NUMBER < 0x10100000L
    SSL_library_init();
    SSL_load_error_strings();
#else
    OPENSSL_init_ssl(OPENSSL_INIT_LOAD_SSL_STRINGS | OPENSSL_INIT_LOAD_CRYPTO_STRINGS, NULL);
#endif

#if OPENSSL_VERSION_NUMBER < 0x10100000L
    ctx = SSL_CTX_new(SSLv23_client_method());
#else
    ctx = SSL_CTX_new(TLS_client_method());
#endif
    if (!ctx) {
        fprintf(stderr, "SSL_CTX_new failed\n");
        goto cleanup;
    }

    SSL_CTX_set_options(ctx, SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3);

    bio = BIO_new_ssl_connect(ctx);
    if (!bio) {
        fprintf(stderr, "BIO_new_ssl_connect failed\n");
        goto cleanup;
    }

    BIO_get_ssl(bio, &ssl);
    if (!ssl) {
        fprintf(stderr, "BIO_get_ssl failed\n");
        goto cleanup;
    }

    char host_port[256];
    snprintf(host_port, sizeof(host_port), "%s:%s", argv[1], argv[2]);
    BIO_set_conn_hostname(bio, host_port);

#if VERIFY_CERTIFICATE
    #if OPENSSL_VERSION_NUMBER >= 0x10002000L
        X509_VERIFY_PARAM *param = SSL_get0_param(ssl);
        X509_VERIFY_PARAM_set1_host(param, argv[1], 0);
        SSL_set_verify(ssl, SSL_VERIFY_PEER, NULL);
    #endif
#else
    SSL_set_verify(ssl, SSL_VERIFY_NONE, NULL);
#endif

    if (BIO_do_connect(bio) <= 0) {
        fprintf(stderr, "BIO_do_connect failed\n");
        goto cleanup;
    }

    if (BIO_do_handshake(bio) <= 0) {
        fprintf(stderr, "BIO_do_handshake failed\n");
        goto cleanup;
    }

    if (BIO_puts(bio, argv[3]) <= 0) {
        fprintf(stderr, "BIO_puts failed\n");
        goto cleanup;
    }

    int len = BIO_read(bio, buf, sizeof(buf)-1);
    if (len > 0) {
        buf[len] = '\0';
        printf("Received: %s", buf);
        ret = 0;
    }

cleanup:
    if (ret != 0) {
        ERR_print_errors_fp(stderr);
    }
    BIO_free_all(bio);
    SSL_CTX_free(ctx);

#if OPENSSL_VERSION_NUMBER < 0x10100000L
    ERR_free_strings();
    EVP_cleanup();
#endif

    return ret;
}
