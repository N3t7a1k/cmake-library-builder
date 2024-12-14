#include <stdio.h>
#include <string.h>
#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/error.h"
#include "mbedtls/debug.h"

#define VERIFY_CERTIFICATE 0
#define BUFFER_SIZE 2048

int main(int argc, char *argv[]) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <hostname> <port> <message>\n", argv[0]);
        return 1;
    }

    int ret = 1;
    mbedtls_net_context server_fd;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context ctr_drbg;
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config conf;
    unsigned char buf[BUFFER_SIZE];
    const char *pers = "ssl_client";

    mbedtls_net_init(&server_fd);
    mbedtls_ssl_init(&ssl);
    mbedtls_ssl_config_init(&conf);
    mbedtls_entropy_init(&entropy);
    mbedtls_ctr_drbg_init(&ctr_drbg);

    // RNG 초기화
    if ((ret = mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy,
                                    (const unsigned char *)pers, strlen(pers))) != 0) {
        fprintf(stderr, "mbedtls_ctr_drbg_seed failed: %d\n", ret);
        goto cleanup;
    }

    // SSL 설정
    if ((ret = mbedtls_ssl_config_defaults(&conf,
                                         MBEDTLS_SSL_IS_CLIENT,
                                         MBEDTLS_SSL_TRANSPORT_STREAM,
                                         MBEDTLS_SSL_PRESET_DEFAULT)) != 0) {
        fprintf(stderr, "mbedtls_ssl_config_defaults failed: %d\n", ret);
        goto cleanup;
    }

    mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &ctr_drbg);

#if VERIFY_CERTIFICATE
    mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_REQUIRED);
#else
    mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_NONE);
#endif

    if ((ret = mbedtls_ssl_setup(&ssl, &conf)) != 0) {
        fprintf(stderr, "mbedtls_ssl_setup failed: %d\n", ret);
        goto cleanup;
    }

    if ((ret = mbedtls_ssl_set_hostname(&ssl, argv[1])) != 0) {
        fprintf(stderr, "mbedtls_ssl_set_hostname failed: %d\n", ret);
        goto cleanup;
    }

    // 서버 연결
    if ((ret = mbedtls_net_connect(&server_fd, argv[1], argv[2], 
                                  MBEDTLS_NET_PROTO_TCP)) != 0) {
        fprintf(stderr, "mbedtls_net_connect failed: %d\n", ret);
        goto cleanup;
    }

    mbedtls_ssl_set_bio(&ssl, &server_fd, mbedtls_net_send, mbedtls_net_recv, NULL);

    // SSL 핸드셰이크
    while ((ret = mbedtls_ssl_handshake(&ssl)) != 0) {
        if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
            fprintf(stderr, "mbedtls_ssl_handshake failed: %d\n", ret);
            goto cleanup;
        }
    }

    // 메시지 전송
    if ((ret = mbedtls_ssl_write(&ssl, (const unsigned char *)argv[3], 
                                strlen(argv[3]))) <= 0) {
        fprintf(stderr, "mbedtls_ssl_write failed: %d\n", ret);
        goto cleanup;
    }

    // 응답 수신
    ret = mbedtls_ssl_read(&ssl, buf, BUFFER_SIZE - 1);
    if (ret > 0) {
        buf[ret] = '\0';
        printf("Received: %s", (char *)buf);
        ret = 0;
    }

cleanup:
    if (ret != 0) {
        char error_buf[100];
        mbedtls_strerror(ret, error_buf, sizeof(error_buf));
        fprintf(stderr, "Error: %s\n", error_buf);
    }

    mbedtls_net_free(&server_fd);
    mbedtls_ssl_free(&ssl);
    mbedtls_ssl_config_free(&conf);
    mbedtls_ctr_drbg_free(&ctr_drbg);
    mbedtls_entropy_free(&entropy);

    return ret;
}