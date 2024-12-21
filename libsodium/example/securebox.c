#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sodium.h>

#define MESSAGE_LEN 1024
#define CHUNK_SIZE 4096

void print_hex(const unsigned char *data, size_t len) {
  for (size_t i = 0; i < len; i++) {
    printf("%02x", data[i]);
  }
  printf("\n");
}

void generate_key(void) {
  unsigned char key[crypto_secretbox_KEYBYTES];
  crypto_secretbox_keygen(key);

  printf("Generated key (hex): ");
  print_hex(key, crypto_secretbox_KEYBYTES);
}

int hex_to_bytes(const char *hex_str, unsigned char *bytes, size_t bytes_len) {
  if (strlen(hex_str) != bytes_len * 2) {
    return -1;
  }

  for (size_t i = 0; i < bytes_len; i++) {
    int value;
    if (sscanf(hex_str + i * 2, "%02x", &value) != 1) {
      return -1;
    }
    bytes[i] = (unsigned char)value;
  }
  return 0;
}

int encrypt_file(const char *key_hex, const char *input_file, const char *output_file) {
  unsigned char key[crypto_secretbox_KEYBYTES];
  unsigned char nonce[crypto_secretbox_NONCEBYTES];
  unsigned char buf_in[CHUNK_SIZE];
  unsigned char buf_out[CHUNK_SIZE + crypto_secretbox_MACBYTES];
  FILE *fp_in, *fp_out;

  if (hex_to_bytes(key_hex, key, crypto_secretbox_KEYBYTES) != 0) {
    fprintf(stderr, "Error: Invalid key format\n");
    return -1;
  }

  randombytes_buf(nonce, sizeof nonce);

  if ((fp_in = fopen(input_file, "rb")) == NULL) {
    fprintf(stderr, "Error: Cannot open input file\n");
    return -1;
  }

  if ((fp_out = fopen(output_file, "wb")) == NULL) {
    fclose(fp_in);
    fprintf(stderr, "Error: Cannot create output file\n");
    return -1;
  }

  fwrite(nonce, 1, sizeof nonce, fp_out);

  while (!feof(fp_in)) {
    size_t bytes_read = fread(buf_in, 1, CHUNK_SIZE, fp_in);
    if (bytes_read > 0) {
      unsigned long long cipher_len;
      crypto_secretbox_easy(buf_out, buf_in, bytes_read, nonce, key);
      fwrite(buf_out, 1, bytes_read + crypto_secretbox_MACBYTES, fp_out);
    }
  }

  fclose(fp_in);
  fclose(fp_out);
  return 0;
}

int decrypt_file(const char *key_hex, const char *input_file, const char *output_file) {
  unsigned char key[crypto_secretbox_KEYBYTES];
  unsigned char nonce[crypto_secretbox_NONCEBYTES];
  unsigned char buf_in[CHUNK_SIZE + crypto_secretbox_MACBYTES];
  unsigned char buf_out[CHUNK_SIZE];
  FILE *fp_in, *fp_out;

  if (hex_to_bytes(key_hex, key, crypto_secretbox_KEYBYTES) != 0) {
    fprintf(stderr, "Error: Invalid key format\n");
    return -1;
  }

  if ((fp_in = fopen(input_file, "rb")) == NULL) {
    fprintf(stderr, "Error: Cannot open input file\n");
    return -1;
  }

  if ((fp_out = fopen(output_file, "wb")) == NULL) {
    fclose(fp_in);
    fprintf(stderr, "Error: Cannot create output file\n");
    return -1;
  }

  if (fread(nonce, 1, sizeof nonce, fp_in) != sizeof nonce) {
    fclose(fp_in);
    fclose(fp_out);
    fprintf(stderr, "Error: Invalid encrypted file format\n");
    return -1;
  }

  while (!feof(fp_in)) {
    size_t bytes_read = fread(buf_in, 1, CHUNK_SIZE + crypto_secretbox_MACBYTES, fp_in);
    if (bytes_read > crypto_secretbox_MACBYTES) {
      if (crypto_secretbox_open_easy(buf_out, buf_in, bytes_read, nonce, key) != 0) {
        fclose(fp_in);
        fclose(fp_out);
        fprintf(stderr, "Error: Decryption failed\n");
        return -1;
      }
      fwrite(buf_out, 1, bytes_read - crypto_secretbox_MACBYTES, fp_out);
    }
  }

  fclose(fp_in);
  fclose(fp_out);
  return 0;
}

int main(int argc, char *argv[]) {
  if (sodium_init() < 0) {
    fprintf(stderr, "Error: Failed to initialize libsodium\n");
    return 1;
  }

  if (argc < 2) {
    printf("Usage:\n");
    printf("  Generate new key:   %s keygen\n", argv[0]);
    printf("  Encrypt file:       %s encrypt <key> <input_file> <output_file>\n", argv[0]);
    printf("  Decrypt file:       %s decrypt <key> <input_file> <output_file>\n", argv[0]);
    return 1;
  }

  if (strcmp(argv[1], "keygen") == 0) {
    generate_key();
  }
  else if (strcmp(argv[1], "encrypt") == 0) {
    if (argc < 5) {
      fprintf(stderr, "Error: Not enough arguments for encryption\n");
      return 1;
    }
    if (encrypt_file(argv[2], argv[3], argv[4]) == 0) {
      printf("Encryption completed successfully\n");
    }
  }
  else if (strcmp(argv[1], "decrypt") == 0) {
    if (argc < 5) {
      fprintf(stderr, "Error: Not enough arguments for decryption\n");
      return 1;
    }
    if (decrypt_file(argv[2], argv[3], argv[4]) == 0) {
      printf("Decryption completed successfully\n");
    }
  }
  else {
    fprintf(stderr, "Error: Unknown command '%s'\n", argv[1]);
    return 1;
  }

  return 0;
}
