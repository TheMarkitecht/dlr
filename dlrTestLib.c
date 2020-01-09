#include <string.h>
#include <stdlib.h>
#include <stdint.h>

typedef uint8_t u8;
typedef uint32_t u32;

/* **********************  EXECUTABLE CODE BELOW  ***************************** */

extern long int test_strtol(const char *nptr, char **endptr, int base);

long int test_strtol(const char *nptr, char **endptr, int base) {
    // wrapper to help debugging.
    return strtol(nptr, endptr, base);
}

