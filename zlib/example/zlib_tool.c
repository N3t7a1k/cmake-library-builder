#include <stdio.h>
#include <string.h>
#include <zlib.h>

#define CHUNK 16384

int compress_file(const char* input_path, const char* output_path) {
    FILE* input = fopen(input_path, "rb");
    if (!input) {
        fprintf(stderr, "Cannot open input file: %s\n", input_path);
        return -1;
    }

    FILE* output = fopen(output_path, "wb");
    if (!output) {
        fprintf(stderr, "Cannot create output file: %s\n", output_path);
        fclose(input);
        return -1;
    }

    unsigned char in[CHUNK];
    unsigned char out[CHUNK];
    z_stream strm;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;

    if (deflateInit(&strm, Z_DEFAULT_COMPRESSION) != Z_OK) {
        fprintf(stderr, "Failed to initialize deflate\n");
        return -1;
    }

    do {
        strm.avail_in = fread(in, 1, CHUNK, input);
        if (ferror(input)) {
            deflateEnd(&strm);
            fclose(input);
            fclose(output);
            return -1;
        }

        strm.next_in = in;
        do {
            strm.avail_out = CHUNK;
            strm.next_out = out;

            deflate(&strm, feof(input) ? Z_FINISH : Z_NO_FLUSH);
            
            int have = CHUNK - strm.avail_out;
            if (fwrite(out, 1, have, output) != have || ferror(output)) {
                deflateEnd(&strm);
                fclose(input);
                fclose(output);
                return -1;
            }
        } while (strm.avail_out == 0);

    } while (!feof(input));

    deflateEnd(&strm);
    fclose(input);
    fclose(output);
    return 0;
}

int decompress_file(const char* input_path, const char* output_path) {
    FILE* input = fopen(input_path, "rb");
    if (!input) {
        fprintf(stderr, "Cannot open input file: %s\n", input_path);
        return -1;
    }

    FILE* output = fopen(output_path, "wb");
    if (!output) {
        fprintf(stderr, "Cannot create output file: %s\n", output_path);
        fclose(input);
        return -1;
    }

    unsigned char in[CHUNK];
    unsigned char out[CHUNK];
    z_stream strm;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.avail_in = 0;
    strm.next_in = Z_NULL;

    if (inflateInit(&strm) != Z_OK) {
        fprintf(stderr, "Failed to initialize inflate\n");
        return -1;
    }

    do {
        strm.avail_in = fread(in, 1, CHUNK, input);
        if (ferror(input)) {
            inflateEnd(&strm);
            fclose(input);
            fclose(output);
            return -1;
        }
        if (strm.avail_in == 0)
            break;

        strm.next_in = in;
        do {
            strm.avail_out = CHUNK;
            strm.next_out = out;

            int ret = inflate(&strm, Z_NO_FLUSH);
            if (ret != Z_OK && ret != Z_STREAM_END) {
                inflateEnd(&strm);
                fclose(input);
                fclose(output);
                return -1;
            }

            int have = CHUNK - strm.avail_out;
            if (fwrite(out, 1, have, output) != have || ferror(output)) {
                inflateEnd(&strm);
                fclose(input);
                fclose(output);
                return -1;
            }
        } while (strm.avail_out == 0);

    } while (1);

    inflateEnd(&strm);
    fclose(input);
    fclose(output);
    return 0;
}

int main(int argc, char* argv[]) {
    if (argc != 3 || (strcmp(argv[1], "-c") != 0 && strcmp(argv[1], "-d") != 0)) {
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "  Compress:   %s -c <file>\n", argv[0]);
        fprintf(stderr, "  Decompress: %s -d <file.z>\n", argv[0]);
        return 1;
    }

    const char* input_path = argv[2];
    char output_path[1024];

    if (strcmp(argv[1], "-c") == 0) {
        snprintf(output_path, sizeof(output_path), "%s.z", input_path);
        printf("Compressing %s to %s\n", input_path, output_path);
        if (compress_file(input_path, output_path) != 0) {
            fprintf(stderr, "Compression failed\n");
            return 1;
        }
        printf("Compression completed\n");
    } else {
        size_t len = strlen(input_path);
        if (len < 2 || input_path[len-2] != '.' || input_path[len-1] != 'z') {
            fprintf(stderr, "Input file must have .z extension\n");
            return 1;
        }
        strncpy(output_path, input_path, len-2);
        output_path[len-2] = '\0';
        
        printf("Decompressing %s to %s\n", input_path, output_path);
        if (decompress_file(input_path, output_path) != 0) {
            fprintf(stderr, "Decompression failed\n");
            return 1;
        }
        printf("Decompression completed\n");
    }

    return 0;
}
