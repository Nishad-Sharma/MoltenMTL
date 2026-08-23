#include "shader_source.h"

#include <stdio.h>
#include <stdlib.h>

char* readShaderSource(const char* path)
{
    FILE* file = fopen(path, "rb");
    if (file == NULL || fseek(file, 0, SEEK_END) != 0) {
        if (file != NULL) {
            fclose(file);
        }
        return NULL;
    }

    const long fileSize = ftell(file);
    if (fileSize < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }

    char* source = malloc((size_t)fileSize + 1);
    if (source == NULL) {
        fclose(file);
        return NULL;
    }

    const size_t bytesRead = fread(source, 1, (size_t)fileSize, file);
    fclose(file);
    if (bytesRead != (size_t)fileSize) {
        free(source);
        return NULL;
    }

    source[bytesRead] = '\0';
    return source;
}
