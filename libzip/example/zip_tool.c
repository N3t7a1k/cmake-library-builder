#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zip.h>
#include <sys/stat.h>
#include <dirent.h>

#define CHUNK 16384

int is_directory(const char* path) {
    struct stat path_stat;
    if (stat(path, &path_stat) != 0) {
        return 0;
    }
    return S_ISDIR(path_stat.st_mode);
}

int add_file_to_zip(zip_t *zipper, const char* filepath, const char* zip_path) {
    FILE *file = fopen(filepath, "rb");
    if (!file) {
        fprintf(stderr, "Failed to open file: %s\n", filepath);
        return -1;
    }

    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    char *buffer = malloc(file_size);
    if (!buffer) {
        fclose(file);
        return -1;
    }
    
    if (fread(buffer, 1, file_size, file) != file_size) {
        fprintf(stderr, "Failed to read file: %s\n", filepath);
        free(buffer);
        fclose(file);
        return -1;
    }
    fclose(file);

    zip_source_t *source = zip_source_buffer(zipper, buffer, file_size, 1);
    if (!source) {
        fprintf(stderr, "Failed to create source for file: %s\n", filepath);
        free(buffer);
        return -1;
    }

    zip_int64_t index = zip_file_add(zipper, zip_path, source, ZIP_FL_ENC_UTF_8);
    if (index < 0) {
        fprintf(stderr, "Failed to add file to zip: %s\n", zip_strerror(zipper));
        zip_source_free(source);
        return -1;
    }

    return 0;
}

int add_dir_to_zip(zip_t *zipper, const char* dir_path, const char* zip_path) {
    DIR *dir = opendir(dir_path);
    if (!dir) {
        fprintf(stderr, "Failed to open directory: %s\n", dir_path);
        return -1;
    }

    if (strlen(zip_path) > 0) {
        char zip_dir_path[1024];
        snprintf(zip_dir_path, sizeof(zip_dir_path), "%s/", zip_path);
        if (zip_dir_add(zipper, zip_dir_path, ZIP_FL_ENC_UTF_8) < 0) {
            fprintf(stderr, "Failed to add directory to zip: %s\n", zip_strerror(zipper));
            closedir(dir);
            return -1;
        }
    }

    struct dirent *entry;
    while ((entry = readdir(dir))) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        char full_path[1024];
        char new_zip_path[1024];
        snprintf(full_path, sizeof(full_path), "%s/%s", dir_path, entry->d_name);
        snprintf(new_zip_path, sizeof(new_zip_path), "%s%s%s", 
                zip_path, 
                (strlen(zip_path) > 0) ? "/" : "",
                entry->d_name);

        if (is_directory(full_path)) {
            if (add_dir_to_zip(zipper, full_path, new_zip_path) < 0) {
                closedir(dir);
                return -1;
            }
        } else {
            if (add_file_to_zip(zipper, full_path, new_zip_path) < 0) {
                closedir(dir);
                return -1;
            }
        }
    }

    closedir(dir);
    return 0;
}

int create_zip(const char* zip_path, const char* source_path) {
    int err = 0;
    zip_t *zipper = zip_open(zip_path, ZIP_CREATE | ZIP_TRUNCATE, &err);
    
    if (!zipper) {
        zip_error_t error;
        zip_error_init_with_code(&error, err);
        fprintf(stderr, "Failed to create zip: %s\n", zip_error_strerror(&error));
        zip_error_fini(&error);
        return -1;
    }

    int result;
    const char *base_name = strrchr(source_path, '/');
    base_name = base_name ? base_name + 1 : source_path;
    
    if (is_directory(source_path)) {
        result = add_dir_to_zip(zipper, source_path, base_name);
    } else {
        result = add_file_to_zip(zipper, source_path, base_name);
    }

    if (zip_close(zipper) < 0) {
        fprintf(stderr, "Failed to close zip file\n");
        return -1;
    }

    return result;
}

int extract_zip(const char* zip_path, const char* extract_dir) {
    int err = 0;
    zip_t *zip = zip_open(zip_path, 0, &err);
    
    if (!zip) {
        zip_error_t error;
        zip_error_init_with_code(&error, err);
        fprintf(stderr, "Failed to open zip: %s\n", zip_error_strerror(&error));
        zip_error_fini(&error);
        return -1;
    }

    zip_int64_t num_entries = zip_get_num_entries(zip, 0);
    for (zip_int64_t i = 0; i < num_entries; i++) {
        const char* name = zip_get_name(zip, i, 0);
        char full_path[1024];
        snprintf(full_path, sizeof(full_path), "./%s", name);

        char *p = strrchr(full_path, '/');
        if (p) {
            *p = '\0';
            #ifdef _WIN32
            mkdir(full_path);
            #else
            mkdir(full_path, 0755);
            #endif
            *p = '/';
        }

        if (name[strlen(name) - 1] == '/') {
            #ifdef _WIN32
            mkdir(full_path);
            #else
            mkdir(full_path, 0755);
            #endif
            continue;
        }

        zip_file_t *file = zip_fopen_index(zip, i, 0);
        if (!file) {
            fprintf(stderr, "Failed to open file in zip: %s\n", zip_strerror(zip));
            continue;
        }

        FILE *out = fopen(full_path, "wb");
        if (!out) {
            fprintf(stderr, "Failed to create output file: %s\n", full_path);
            zip_fclose(file);
            continue;
        }

        char buffer[CHUNK];
        zip_int64_t count;
        while ((count = zip_fread(file, buffer, sizeof(buffer))) > 0) {
            fwrite(buffer, 1, count, out);
        }

        zip_fclose(file);
        fclose(out);
    }

    if (zip_close(zip) < 0) {
        fprintf(stderr, "Failed to close zip file\n");
        return -1;
    }

    return 0;
}

int main(int argc, char* argv[]) {
    if (argc != 3 || (strcmp(argv[1], "-c") != 0 && strcmp(argv[1], "-x") != 0)) {
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "  Create zip:    %s -c <file|directory>\n", argv[0]);
        fprintf(stderr, "  Extract zip:   %s -x <file.zip>\n", argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "-c") == 0) {
        const char* source_path = argv[2];
        char zip_path[1024];
        snprintf(zip_path, sizeof(zip_path), "%s.zip", source_path);
        
        printf("Creating zip archive %s from %s\n", zip_path, source_path);
        if (create_zip(zip_path, source_path) != 0) {
            fprintf(stderr, "Failed to create zip archive\n");
            return 1;
        }
        printf("Zip archive created successfully\n");
    } else {
        const char* zip_path = argv[2];
        size_t len = strlen(zip_path);
        
        if (len < 5 || strcmp(zip_path + len - 4, ".zip") != 0) {
            fprintf(stderr, "Input file must have .zip extension\n");
            return 1;
        }
        
        printf("Extracting %s to current directory\n", zip_path);
        if (extract_zip(zip_path, ".") != 0) {
            fprintf(stderr, "Failed to extract zip archive\n");
            return 1;
        }
        printf("Zip archive extracted successfully\n");
    }

    return 0;
}
