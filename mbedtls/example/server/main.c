#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/error.h"
#include "mbedtls/x509.h"
#include "mbedtls/x509_crt.h"
#include "mbedtls/pk.h"

#define BUFFER_SIZE 2048

static int generate_self_signed_cert(mbedtls_x509_crt *cert, mbedtls_pk_context *key) {
   int ret;
   mbedtls_x509write_cert crt;
   mbedtls_entropy_context entropy;
   mbedtls_ctr_drbg_context ctr_drbg;
   const char *pers = "cert_gen";
   mbedtls_mpi serial;
   char not_before[16];
   char not_after[16];
   unsigned char output_buf[4096];
   time_t now;
   struct tm *timeinfo;
   
   mbedtls_x509write_crt_init(&crt);
   mbedtls_x509write_crt_set_md_alg(&crt, MBEDTLS_MD_SHA256);
   mbedtls_entropy_init(&entropy);
   mbedtls_ctr_drbg_init(&ctr_drbg);
   mbedtls_mpi_init(&serial);
   
   mbedtls_x509write_crt_set_version(&crt, MBEDTLS_X509_CRT_VERSION_3);
   
   time(&now);
   timeinfo = gmtime(&now);
   strftime(not_before, sizeof(not_before), "%Y%m%d%H%M%S", timeinfo);
   now += 365 * 24 * 3600;
   timeinfo = gmtime(&now);
   strftime(not_after, sizeof(not_after), "%Y%m%d%H%M%S", timeinfo);
   
   if ((ret = mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy,
                                   (const unsigned char *)pers, strlen(pers))) != 0) {
       goto exit;
   }
   
   if ((ret = mbedtls_pk_setup(key, mbedtls_pk_info_from_type(MBEDTLS_PK_RSA))) != 0) {
       goto exit;
   }
   
   if ((ret = mbedtls_rsa_gen_key(mbedtls_pk_rsa(*key), mbedtls_ctr_drbg_random, &ctr_drbg,
                                 2048, 65537)) != 0) {
       goto exit;
   }
   
   mbedtls_x509write_crt_set_subject_key(&crt, key);
   mbedtls_x509write_crt_set_issuer_key(&crt, key);
   
   if ((ret = mbedtls_mpi_read_string(&serial, 10, "1")) != 0) {
       goto exit;
   }
   
   if ((ret = mbedtls_x509write_crt_set_serial(&crt, &serial)) != 0) {
       goto exit;
   }
   
   if ((ret = mbedtls_x509write_crt_set_validity(&crt, not_before, not_after)) != 0) {
       goto exit;
   }
   
   if ((ret = mbedtls_x509write_crt_set_subject_name(&crt, "CN=localhost")) != 0) {
       goto exit;
   }
   
   if ((ret = mbedtls_x509write_crt_set_issuer_name(&crt, "CN=localhost")) != 0) {
       goto exit;
   }
   
   if ((ret = mbedtls_x509write_crt_set_basic_constraints(&crt, 0, 0)) != 0) {
       goto exit;
   }
   
   if ((ret = mbedtls_x509write_crt_set_key_usage(&crt, 
           MBEDTLS_X509_KU_DIGITAL_SIGNATURE |
           MBEDTLS_X509_KU_KEY_ENCIPHERMENT)) != 0) {
       goto exit;
   }
   
   ret = mbedtls_x509write_crt_der(&crt, output_buf, sizeof(output_buf),
                                  mbedtls_ctr_drbg_random, &ctr_drbg);
   if (ret < 0) {
       goto exit;
   }
   
   if ((ret = mbedtls_x509_crt_parse_der(cert, 
           output_buf + sizeof(output_buf) - ret, ret)) != 0) {
       goto exit;
   }
   
exit:
   mbedtls_x509write_crt_free(&crt);
   mbedtls_mpi_free(&serial);
   mbedtls_ctr_drbg_free(&ctr_drbg);
   mbedtls_entropy_free(&entropy);
   return ret;
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
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config conf;
    mbedtls_x509_crt srvcert;
    mbedtls_pk_context pkey;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context ctr_drbg;
    const char *pers = "ssl_server";
    
    mbedtls_ssl_init(&ssl);
    mbedtls_ssl_config_init(&conf);
    mbedtls_x509_crt_init(&srvcert);
    mbedtls_pk_init(&pkey);
    mbedtls_entropy_init(&entropy);
    mbedtls_ctr_drbg_init(&ctr_drbg);
    
    if ((ret = mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy,
                                    (const unsigned char *)pers, strlen(pers))) != 0) {
        printf("Failed to seed RNG: %d\n", ret);
        goto cleanup;
    }
    
    if ((ret = generate_self_signed_cert(&srvcert, &pkey)) != 0) {
        printf("Failed to generate certificate: %d\n", ret);
        goto cleanup;
    }
    
    if ((ret = mbedtls_ssl_config_defaults(&conf,
                                         MBEDTLS_SSL_IS_SERVER,
                                         MBEDTLS_SSL_TRANSPORT_STREAM,
                                         MBEDTLS_SSL_PRESET_DEFAULT)) != 0) {
        printf("Failed to set SSL config defaults: %d\n", ret);
        goto cleanup;
    }
    
    mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &ctr_drbg);
    
    if ((ret = mbedtls_ssl_conf_own_cert(&conf, &srvcert, &pkey)) != 0) {
        printf("Failed to set certificate: %d\n", ret);
        goto cleanup;
    }
    
    sockfd = create_socket(port);
    if (sockfd < 0) goto cleanup;
    
    printf("Server listening on port %d\n", port);
    
    while(1) {
        struct sockaddr_in client_addr;
        unsigned int client_len = sizeof(client_addr);
        int client_fd;
        unsigned char buf[BUFFER_SIZE];
        
        client_fd = accept(sockfd, (struct sockaddr*)&client_addr, &client_len);
        if (client_fd < 0) {
            perror("accept");
            continue;
        }
        
        if ((ret = mbedtls_ssl_setup(&ssl, &conf)) != 0) {
            printf("Failed to setup SSL: %d\n", ret);
            close(client_fd);
            continue;
        }
        
        mbedtls_ssl_set_bio(&ssl, &client_fd, mbedtls_net_send, mbedtls_net_recv, NULL);
        
        while ((ret = mbedtls_ssl_handshake(&ssl)) != 0) {
            if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
                printf("Failed to perform SSL handshake: %d\n", ret);
                break;
            }
        }
        
        if (ret == 0) {
            int len = mbedtls_ssl_read(&ssl, buf, sizeof(buf) - 1);
            if (len > 0) {
                buf[len] = '\0';
                printf("Received: %s", (char *)buf);
                mbedtls_ssl_write(&ssl, buf, len);
            }
        }
        
        mbedtls_ssl_session_reset(&ssl);
        close(client_fd);
    }
    
    ret = 0;
    
cleanup:
    if (ret != 0) {
        char error_buf[100];
        mbedtls_strerror(ret, error_buf, sizeof(error_buf));
        printf("Error: %s\n", error_buf);
    }
    
    if (sockfd >= 0) close(sockfd);
    mbedtls_ssl_free(&ssl);
    mbedtls_ssl_config_free(&conf);
    mbedtls_x509_crt_free(&srvcert);
    mbedtls_pk_free(&pkey);
    mbedtls_entropy_free(&entropy);
    mbedtls_ctr_drbg_free(&ctr_drbg);
    
    return ret;
}
