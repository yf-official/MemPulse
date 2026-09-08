#include "CMemoryBridge.h"

#include <libproc.h>
#include <string.h>
#include <sys/resource.h>

uint64_t mp_process_phys_footprint(pid_t pid, int *error_code) {
    struct rusage_info_v4 info;
    memset(&info, 0, sizeof(info));
    int rc = proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)&info);
    if (error_code != NULL) {
        *error_code = rc;
    }
    return rc == 0 ? info.ri_phys_footprint : 0;
}
