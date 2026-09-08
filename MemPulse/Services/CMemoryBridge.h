#ifndef CMemoryBridge_h
#define CMemoryBridge_h

#include <stdint.h>
#include <sys/types.h>

uint64_t mp_process_phys_footprint(pid_t pid, int *error_code);

#endif
