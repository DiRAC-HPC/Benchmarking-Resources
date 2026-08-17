## Technical specifications:

Node: `mad12`, 2 × AMD EPYC 9755 (Zen 5 "classic", 128 cores/socket), NPS=4,
DDR5-6400 (24 × 64 GiB DIMMs, 1 DIMM per channel, 0 empty slots, confirmed by
`dmidecode -t 17`). SMT on: 512 logical cpus, 0-255 physical, 256-511 siblings.
All runs below use physical cores only, one thread per core.

| Component                   | Per-Core          | Per-CCD (8 cores) | Per-NUMA (4 CCDs)          | Per-Socket (16 CCDs) | Node (2 Sockets) |
|-----------------------------|-------------------|-------------------|-----------------------------|-----------------------|------------------|
| Cores                       | 1                 | 8                 | 32                          | 128                   | 256              |
| L1 Cache                    | 48 KB D + 32 KB I | 640 KB total      | 2.5 MB                      | 10 MB                 | 20 MB            |
| L2 Cache                    | 1 MB              | 8 MB              | 32 MB                       | 128 MB                | 256 MB           |
| L3 Cache                    | —                 | 32 MB shared      | 128 MB (4 × 32 MB)          | 512 MB (16 × 32 MB)   | 1024 MB (1 GiB)  |
| Memory Channels (DDR5-6400) | —                 | —                 | 3 channels                  | 12 channels           | 24 channels      |
| NUMA Domains (NPS=4)        | —                 | —                 | 1 NUMA domain               | 4 NUMA domains        | 8 NUMA domains   |
| Topology Mapping            | —                 | 1 CCD             | 4 CCDs + 3 memory channels  | 16 CCDs total         | 32 CCDs total    |

Notes:

- Hardware limits: 1.21 GHz - 4.12 GHz
- Nominal Performance: 2.70 GHz; boost active
- Lowest Non-linear Performance: 2.10 GHz
- Lowest Performance: 1.20 GHz
- AVX-512: full 512-bit execution path and register support by default,
  changeable in BIOS. mad12's current setting is not confirmed.
- Memory controllers reside in the I/O die; the CCD-to-memory affinity is determined by NUMA mapping.
- In NPS=4 mode, each NUMA domain contains:
  - 32 cores
  - 128 MB L3 cache
  - 3 DDR5 channels
- L3 cache is private per CCD and not shared across CCDs.
- L3 cache acts as a victim cache for L2, storing evicted lines but not fetching directly from DRAM (*).

## Peaks

### Double avx512 fma flops

Theoretical:

- cores × frequency × (fma units × fma ops) × (vector size / dp size)
- cores × frequency × (2 × 2) × (512/64) = cores × frequency × 32

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -w M0:524288B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -w M0:4194304B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-31 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -w M0:16777216B:32
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-127 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -w M0:16777216B:32 -w M1:16777216B:32 -w M2:16777216B:32 -w M3:16777216B:32
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-255 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -w M0:16777216B:32 -w M1:16777216B:32 -w M2:16777216B:32 -w M3:16777216B:32 -w M4:16777216B:32 -w M5:16777216B:32 -w M6:16777216B:32 -w M7:16777216B:32
```

Boost
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 132.4                 | 132.17             | 99.81     | 4.139           | 31.94          |
| 8     | 1     | 1058.6                | 1056.23            | 99.79     | 4.135           | 31.93          |
| 32    | 1     | 3940.8                | 3920.43            | 99.49     | 3.848           | 31.83          |
| 128   | 4     | 12733.0               | 12570.12           | 98.72     | 3.109           | 31.59          |
| 256   | 8     | 25502.4               | 25058.94           | 98.26     | 3.113           | 31.44          |

Fixed (`cpupower` pinned)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 77.2                  | 76.95              | 99.73     | 2.411           | 31.91          |
| 8     | 1     | 617.5                 | 615.83             | 99.73     | 2.412           | 31.91          |
| 32    | 1     | 2469.2                | 2453.70            | 99.37     | 2.411           | 31.80          |
| 128   | 4     | 9874.7                | 9796.35            | 99.21     | 2.411           | 31.75          |
| 256   | 8     | 19773.9               | 19519.71           | 98.71     | 2.414           | 31.59          |

### Double avx512 fma + add flops

Theoretical:

- cores × frequency × ((fma units × fma ops) × (512/64) + (add units × (512/64)))
- cores × frequency × (32 + 16) = cores × frequency × 48

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_DP -m likwid-bench -t peakflops_amd_zen_avx512_fma_add -w M0:524288B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7 -g FLOPS_DP -m likwid-bench -t peakflops_amd_zen_avx512_fma_add -w M0:4194304B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-31 -g FLOPS_DP -m likwid-bench -t peakflops_amd_zen_avx512_fma_add -w M0:16777216B:32
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-127 -g FLOPS_DP -m likwid-bench -t peakflops_amd_zen_avx512_fma_add -w M0:16777216B:32 -w M1:16777216B:32 -w M2:16777216B:32 -w M3:16777216B:32
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-255 -g FLOPS_DP -m likwid-bench -t peakflops_amd_zen_avx512_fma_add -w M0:16777216B:32 -w M1:16777216B:32 -w M2:16777216B:32 -w M3:16777216B:32 -w M4:16777216B:32 -w M5:16777216B:32 -w M6:16777216B:32 -w M7:16777216B:32
```

Boost
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 198.6                 | 182.93             | 92.09     | 4.138           | 44.20          |
| 8     | 1     | 1587.6                | 1460.90            | 92.02     | 4.134           | 44.17          |
| 32    | 1     | 5493.6                | 5022.48            | 91.43     | 3.577           | 43.88          |
| 128   | 4     | 16389.2               | 14873.67           | 90.76     | 2.668           | 43.56          |
| 256   | 8     | 32970.0               | 29494.10           | 89.46     | 2.683           | 42.94          |

Fixed (`cpupower` pinned)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 115.8                 | 106.59             | 92.04     | 2.413           | 44.18          |
| 8     | 1     | 926.2                 | 852.22             | 92.01     | 2.412           | 44.16          |
| 32    | 1     | 3707.6                | 3394.79            | 91.56     | 2.414           | 43.95          |
| 128   | 4     | 14818.9               | 13530.51           | 91.31     | 2.412           | 43.83          |
| 256   | 8     | 29666.5               | 27043.12           | 91.16     | 2.414           | 43.76          |

### Single avx512 fma flops:

Theoretical:

- cores × frequency × (fma units × fma ops) × (vector size / sp size)
- cores × frequency × (2 × 2) × (512/32) = cores × frequency × 64

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -w M0:524288B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -w M0:4194304B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-31 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -w M0:16777216B:32
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-127 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -w M0:16777216B:32 -w M1:16777216B:32 -w M2:16777216B:32 -w M3:16777216B:32
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-255 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -w M0:16777216B:32 -w M1:16777216B:32 -w M2:16777216B:32 -w M3:16777216B:32 -w M4:16777216B:32 -w M5:16777216B:32 -w M6:16777216B:32 -w M7:16777216B:32
```

Boost
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 264.8                 | 264.31             | 99.85     | 4.136           | 63.90          |
| 8     | 1     | 2117.0                | 2112.30            | 99.78     | 4.135           | 63.86          |
| 32    | 1     | 7885.6                | 7850.44            | 99.56     | 3.850           | 63.71          |
| 128   | 4     | 25462.8               | 25119.57           | 98.65     | 3.108           | 63.14          |
| 256   | 8     | 51033.0               | 50153.46           | 98.28     | 3.115           | 62.90          |

Fixed (`cpupower` pinned)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 154.4                 | 153.99             | 99.74     | 2.412           | 63.84          |
| 8     | 1     | 1234.0                | 1231.20            | 99.77     | 2.410           | 63.86          |
| 32    | 1     | 4935.0                | 4904.72            | 99.39     | 2.410           | 63.61          |
| 128   | 4     | 19754.3               | 19583.70           | 99.14     | 2.411           | 63.45          |
| 256   | 8     | 39556.9               | 39052.39           | 98.72     | 2.414           | 63.18          |

### Single avx512 flops (non-fma kernel):

Theoretical:

- multiply on the 2 FMA-capable units + add on the 2 ADD-only units, running
  concurrently:
- cores × frequency × ((fma units × mul ops) × (vector size / sp size) + (add units × add ops) × (512 / sp size))
- cores × frequency × ((2 × 1) × (512/32) + (2 × 1) × (512/32)) = cores × frequency × (32 + 32) = cores × frequency × 64

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512 -w M0:524288B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512 -w M0:4194304B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-31 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512 -w M0:16777216B:32
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-127 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512 -w M0:16777216B:32 -w M1:16777216B:32 -w M2:16777216B:32 -w M3:16777216B:32
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-255 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512 -w M0:16777216B:32 -w M1:16777216B:32 -w M2:16777216B:32 -w M3:16777216B:32 -w M4:16777216B:32 -w M5:16777216B:32 -w M6:16777216B:32 -w M7:16777216B:32
```

Boost
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 264.8                 | 222.07             | 83.88     | 4.137           | 53.68          |
| 8     | 1     | 2116.8                | 1774.93            | 83.85     | 4.134           | 53.67          |
| 32    | 1     | 7325.0                | 6106.33            | 83.37     | 3.577           | 53.35          |
| 128   | 4     | 21815.6               | 18029.82           | 82.65     | 2.663           | 52.89          |
| 256   | 8     | 43755.0               | 35984.33           | 82.24     | 2.671           | 52.63          |

Fixed (`cpupower` pinned)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 154.3                 | 129.37             | 83.83     | 2.411           | 53.65          |
| 8     | 1     | 1235.7                | 1035.58            | 83.81     | 2.413           | 53.64          |
| 32    | 1     | 4942.3                | 4123.52            | 83.43     | 2.413           | 53.40          |
| 128   | 4     | 19754.9               | 16444.15           | 83.24     | 2.411           | 53.27          |
| 256   | 8     | 39551.7               | 32878.88           | 83.13     | 2.414           | 53.20          |

### Single scalar flops:

Theoretical:

- cores × frequency × (fp pipes × 1 flop) = cores × frequency × 4

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_SP -m likwid-bench -t peakflops_sp -w M0:524288B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7 -g FLOPS_SP -m likwid-bench -t peakflops_sp -w M0:4194304B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-31 -g FLOPS_SP -m likwid-bench -t peakflops_sp -w M0:16777216B:32
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-127 -g FLOPS_SP -m likwid-bench -t peakflops_sp -w M0:16777216B:32 -w M1:16777216B:32 -w M2:16777216B:32 -w M3:16777216B:32
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-255 -g FLOPS_SP -m likwid-bench -t peakflops_sp -w M0:16777216B:32 -w M1:16777216B:32 -w M2:16777216B:32 -w M3:16777216B:32 -w M4:16777216B:32 -w M5:16777216B:32 -w M6:16777216B:32 -w M7:16777216B:32
```

Boost
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 16.6                  | 8.66               | 52.29     | 4.138           | 2.09           |
| 8     | 1     | 132.4                 | 69.15              | 52.24     | 4.137           | 2.09           |
| 32    | 1     | 526.5                 | 274.33             | 52.10     | 4.114           | 2.08           |
| 128   | 4     | 2034.2                | 1053.06            | 51.77     | 3.973           | 2.07           |
| 256   | 8     | 4088.2                | 2111.68            | 51.65     | 3.992           | 2.07           |

Fixed (`cpupower` pinned)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 9.6                   | 5.04               | 52.27     | 2.411           | 2.09           |
| 8     | 1     | 77.2                  | 40.31              | 52.21     | 2.413           | 2.09           |
| 32    | 1     | 308.4                 | 160.13             | 51.93     | 2.409           | 2.08           |
| 128   | 4     | 1234.7                | 640.80             | 51.90     | 2.411           | 2.08           |
| 256   | 8     | 2472.3                | 1280.30            | 51.78     | 2.414           | 2.07           |

### Memory bandwidth:

Theoretical:

- Per channel: DDR5-6400 → 6400 MT/s × 8 bytes = 51.2 GB/s
- Per NUMA domain (NPS=4): 3 channels × 51.2 GB/s = 153.6 GB/s

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0     -g MEM -m likwid-bench -t stream_mem_avx_fma -w M0:536870912B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7   -g MEM -m likwid-bench -t stream_mem_avx_fma -w M0:4294967296B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-31  -g MEM -m likwid-bench -t stream_mem_avx_fma -w M0:17179869184B:32
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-127 -g MEM -m likwid-bench -t stream_mem_avx_fma -w M0:17179869184B:32 -w M1:17179869184B:32 -w M2:17179869184B:32 -w M3:17179869184B:32
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-255 -g MEM -m likwid-bench -t stream_mem_avx_fma -w M0:17179869184B:32 -w M1:17179869184B:32 -w M2:17179869184B:32 -w M3:17179869184B:32 -w M4:17179869184B:32 -w M5:17179869184B:32 -w M6:17179869184B:32 -w M7:17179869184B:32
```

Boost
| Cores | CCDs | NUMAs | Theoretical (GB/s) | Measured (GB/s) | % of Peak | Read (GB/s) | Write (GB/s) |
|-------|------|-------|--------------------|-----------------|-----------|-------------|--------------|
| 1     | 1    | 1     | 153.6              | 54.76           | 35.65     | 36.05       | 18.71        |
| 8     | 1    | 1     | 153.6              | 65.78           | 42.83     | 43.86       | 21.92        |
| 32    | 4    | 1     | 153.6              | 112.18          | 73.03     | 74.79       | 37.39        |
| 128   | 16   | 4     | 614.4              | 447.83          | 72.89     | 298.57      | 149.26       |
| 256   | 32   | 8     | 1228.8             | 893.99          | 72.75     | 596.03      | 297.96       |

Fixed (`cpupower` pinned)
| Cores | CCDs | NUMAs | Theoretical (GB/s) | Measured (GB/s) | % of Peak | Read (GB/s) | Write (GB/s) |
|-------|------|-------|--------------------|-----------------|-----------|-------------|--------------|
| 1     | 1    | 1     | 153.6              | 55.20           | 35.94     | 36.34       | 18.87        |
| 8     | 1    | 1     | 153.6              | 65.37           | 42.56     | 43.59       | 21.78        |
| 32    | 4    | 1     | 153.6              | 112.03          | 72.93     | 74.69       | 37.33        |
| 128   | 16   | 4     | 614.4              | 447.17          | 72.78     | 298.13      | 149.03       |
| 256   | 32   | 8     | 1228.8             | 892.87          | 72.66     | 595.28      | 297.58       |

### L2 bandwidth

Likwid command (scaled for number of cores). Uses the custom "L2BW" group
(~/.likwid/groups/zen5/L2BW.txt on mad12) instead of the built-in "L2CACHE",
since L2CACHE has no bandwidth or clock metrics at all.
``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0     -g L2BW -m likwid-bench -t load -w M0:4194304B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7   -g L2BW -m likwid-bench -t load -w M0:33554432B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-31  -g L2BW -m likwid-bench -t load -w M0:134217728B:32
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-127 -g L2BW -m likwid-bench -t load -w M0:134217728B:32 -w M1:134217728B:32 -w M2:134217728B:32 -w M3:134217728B:32
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-255 -g L2BW -m likwid-bench -t load -w M0:134217728B:32 -w M1:134217728B:32 -w M2:134217728B:32 -w M3:134217728B:32 -w M4:134217728B:32 -w M5:134217728B:32 -w M6:134217728B:32 -w M7:134217728B:32
```

Boost
| Cores | CCDs | NUMAs | Per core (GB/s) | Aggregate (GB/s) | Frequency (GHz) | Per core / Frequency (GB/s/GHz) |
|-------|------|-------|------------------|-------------------|------------------|-----------------------------------|
| 1     | 1    | 1     | 66.06            | 66.06             | 4.139            | 15.96                             |
| 8     | 1    | 1     | 65.81            | 526.47            | 4.136            | 15.91                             |
| 32    | 4    | 1     | 57.95            | 1854.37           | 3.667            | 15.80                             |
| 128   | 16   | 4     | 45.12            | 5775.97           | 2.955            | 15.27                             |
| 256   | 32   | 8     | 44.33            | 11347.81          | 2.985            | 14.85                             |

Fixed (`cpupower` pinned)
| Cores | CCDs | NUMAs | Per core (GB/s) | Aggregate (GB/s) | Frequency (GHz) | Per core / Frequency (GB/s/GHz) |
|-------|------|-------|------------------|-------------------|------------------|-----------------------------------|
| 1     | 1    | 1     | 38.49            | 38.49             | 2.413            | 15.95                             |
| 8     | 1    | 1     | 38.43            | 307.48            | 2.414            | 15.92                             |
| 32    | 4    | 1     | 38.22            | 1223.08           | 2.413            | 15.84                             |
| 128   | 16   | 4     | 36.95            | 4729.74           | 2.411            | 15.33                             |
| 256   | 32   | 8     | 36.94            | 9456.83           | 2.413            | 15.31                             |

### L2 bandwidth (load_avx, 256-bit)

Likwid command (scaled for number of cores):
``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0     -g L2BW -m likwid-bench -t load_avx -w M0:4194304B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7   -g L2BW -m likwid-bench -t load_avx -w M0:33554432B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-31  -g L2BW -m likwid-bench -t load_avx -w M0:134217728B:32
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-127 -g L2BW -m likwid-bench -t load_avx -w M0:134217728B:32 -w M1:134217728B:32 -w M2:134217728B:32 -w M3:134217728B:32
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-255 -g L2BW -m likwid-bench -t load_avx -w M0:134217728B:32 -w M1:134217728B:32 -w M2:134217728B:32 -w M3:134217728B:32 -w M4:134217728B:32 -w M5:134217728B:32 -w M6:134217728B:32 -w M7:134217728B:32
```

Boost
| Cores | CCDs | NUMAs | Per core (GB/s) | Aggregate (GB/s) | Frequency (GHz) | Per core / Frequency (GB/s/GHz) |
|-------|------|-------|------------------|-------------------|------------------|-----------------------------------|
| 1     | 1    | 1     | 130.48           | 130.48            | 4.141            | 31.51                             |
| 8     | 1    | 1     | 108.38           | 867.07            | 4.136            | 26.21                             |
| 32    | 4    | 1     | 88.81            | 2841.93           | 3.493            | 25.42                             |
| 128   | 16   | 4     | 64.74            | 8287.16           | 2.622            | 24.69                             |
| 256   | 32   | 8     | 64.57            | 16529.93          | 2.630            | 24.55                             |

Fixed (`cpupower` pinned)
| Cores | CCDs | NUMAs | Per core (GB/s) | Aggregate (GB/s) | Frequency (GHz) | Per core / Frequency (GB/s/GHz) |
|-------|------|-------|------------------|-------------------|------------------|-----------------------------------|
| 1     | 1    | 1     | 75.72            | 75.72             | 2.414            | 31.36                             |
| 8     | 1    | 1     | 63.37            | 506.93            | 2.413            | 26.26                             |
| 32    | 4    | 1     | 63.06            | 2017.97           | 2.413            | 26.13                             |
| 128   | 16   | 4     | 54.04            | 6916.70           | 2.407            | 22.45                             |
| 256   | 32   | 8     | 60.28            | 15431.18          | 2.410            | 25.01                             |

### L2 bandwidth (load_avx512, 512-bit)

Likwid command (scaled for number of cores):
``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0     -g L2BW -m likwid-bench -t load_avx512 -w M0:4194304B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7   -g L2BW -m likwid-bench -t load_avx512 -w M0:33554432B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-31  -g L2BW -m likwid-bench -t load_avx512 -w M0:134217728B:32
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-127 -g L2BW -m likwid-bench -t load_avx512 -w M0:134217728B:32 -w M1:134217728B:32 -w M2:134217728B:32 -w M3:134217728B:32
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-255 -g L2BW -m likwid-bench -t load_avx512 -w M0:134217728B:32 -w M1:134217728B:32 -w M2:134217728B:32 -w M3:134217728B:32 -w M4:134217728B:32 -w M5:134217728B:32 -w M6:134217728B:32 -w M7:134217728B:32
```

Boost
| Cores | CCDs | NUMAs | Per core (GB/s) | Aggregate (GB/s) | Frequency (GHz) | Per core / Frequency (GB/s/GHz) |
|-------|------|-------|------------------|-------------------|------------------|-----------------------------------|
| 1     | 1    | 1     | 120.75           | 120.75            | 4.141            | 29.16                             |
| 8     | 1    | 1     | 97.60            | 780.78            | 4.137            | 23.59                             |
| 32    | 4    | 1     | 82.13            | 2628.30           | 3.650            | 22.50                             |
| 128   | 16   | 4     | 64.09            | 8203.60           | 2.856            | 22.44                             |
| 256   | 32   | 8     | 64.29            | 16457.81          | 2.855            | 22.52                             |

Fixed (`cpupower` pinned)
| Cores | CCDs | NUMAs | Per core (GB/s) | Aggregate (GB/s) | Frequency (GHz) | Per core / Frequency (GB/s/GHz) |
|-------|------|-------|------------------|-------------------|------------------|-----------------------------------|
| 1     | 1    | 1     | 70.43            | 70.43             | 2.415            | 29.17                             |
| 8     | 1    | 1     | 56.58            | 452.64            | 2.414            | 23.44                             |
| 32    | 4    | 1     | 56.89            | 1820.58           | 2.414            | 23.57                             |
| 128   | 16   | 4     | 50.67            | 6485.47           | 2.411            | 21.02                             |
| 256   | 32   | 8     | 50.91            | 13032.13          | 2.413            | 21.10                             |

Note: measures lower than load_avx (256-bit) at every core count. mad12's
BIOS FP256/FP512 AVX-512 data-path setting is unknown and may be related.

Note2: Further testing on L2 might be required as the variance with fixed frequency is a bit too high.  The size is now at the boundary of L3 (keeping at the L2 boundary only works for single NUMA, but above/below it showed reduced bandwidth) - potentially half of L3 will reduce variance.
