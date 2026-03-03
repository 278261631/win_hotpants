#ifndef HP_COMPAT_H
#define HP_COMPAT_H

/*
 * Small portability shim for Windows/MSVC builds.
 * Keep this header lightweight so core algorithm code stays unchanged.
 */
#ifdef _WIN32
#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif

#ifndef strcasecmp
#define strcasecmp _stricmp
#endif

#ifndef strncasecmp
#define strncasecmp _strnicmp
#endif

static inline int hp_gethostname(char *name, int len) {
    const char *computer_name;
    size_t i;
    if (!name || len <= 1) {
        return -1;
    }
    computer_name = getenv("COMPUTERNAME");
    if (!computer_name || !computer_name[0]) {
        return -1;
    }
    for (i = 0; i < (size_t)(len - 1) && computer_name[i] != '\0'; ++i) {
        name[i] = computer_name[i];
    }
    name[i] = '\0';
    return 0;
}
#else
#include <strings.h>
#include <unistd.h>

#define hp_gethostname gethostname
#endif

#endif /* HP_COMPAT_H */
