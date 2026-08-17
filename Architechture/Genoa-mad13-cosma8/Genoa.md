## Technical specifications:

Node: `mad13`, 2 × AMD EPYC 9654 (Zen 4, 96 cores/socket), NPS=4, DDR5-4800 (24
× 64 GiB DIMMs, 1 DIMM per channel, confirmed by `dmidecode -t 17`). SMT on: 384
logical cpus, 0-191 physical, 192-383 siblings. All runs below use physical
cores only, one thread per core.

| Component                   | Per-Core          | Per-CCD (8 cores) | Per-NUMA (3 CCDs)          | Per-Socket (12 CCDs) | Node (2 Sockets) |
|-----------------------------|-------------------|-------------------|----------------------------|----------------------|------------------|
| Cores                       | 1                 | 8                 | 24                         | 96                   | 192              |
| L1 Cache                    | 32 KB I + 32 KB D | 512 KB total      | 1.5 MB                     | 3 MB                 | 6 MB             |
| L2 Cache                    | 1 MB              | 8 MB              | 24 MB                      | 96 MB                | 192 MB           |
| L3 Cache                    | —                 | 32 MB shared      | 96 MB (3 × 32 MB)          | 384 MB (12 × 32 MB)  | 768 MB           |
| Memory Channels (DDR5-4800) | —                 | —                 | 3 channels                 | 12 channels          | 24 channels      |
| NUMA Domains (NPS=4)        | —                 | —                 | 1 NUMA domain              | 4 NUMA domains       | 8 NUMA domains   |
| Topology Mapping            | —                 | 1 CCD             | 3 CCDs + 3 memory channels | 12 CCDs total        | 24 CCDs total    |

Notes:

- Base and boost clocks:
  - PState-3: 2.4 GHz base, up to 3.7 GHz boost
  - PState-2: 1.9 GHz base, no boost
- Memory controllers reside in the I/O die; the CCD-to-memory affinity is determined by NUMA mapping.
- In NPS=4 mode, each NUMA domain contains:
  - 24 cores
  - 96 MB L3 cache
  - 3 DDR5 channels
- L3 cache is private per CCD and not shared across CCDs.
- L3 cache acts as a victim cache for L2, storing evicted lines but not fetching directly from DRAM (*).
- AVX-512 (512-bit) on Zen4 has 2 256-bit FMA units working in tandem to
  provide a single 512-bit instruction per cycle.
- The core has 4 256-bit FP pipes total: the 2 FMA units above, plus 2
  ADD-only units, which can all work simultaneously.
- The frequency could not be pinned for the PState-3 runs. The Frequency column
  is the measured `Clock [MHz]` for that run and the Theoretical column is
  computed at that clock, not at 3.7 GHz.

## Peaks

### Double avx512 fma flops

Theoretical:

- cores × frequency × (fma units × fma ops) × (vector size / dp size)
- cores × frequency × (1 × 2) × (512/64) = cores × frequency × 16

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -w M0:524288B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -w M0:4194304B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -w M0:12582912B:24
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -w M0:12582912B:24 -w M1:12582912B:24 -w M2:12582912B:24 -w M3:12582912B:24
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -w M0:12582912B:24 -w M1:12582912B:24 -w M2:12582912B:24 -w M3:12582912B:24 -w M4:12582912B:24 -w M5:12582912B:24 -w M6:12582912B:24 -w M7:12582912B:24
```

PState-3 (with boost)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 59.1                  | 58.88              | 99.61     | 3.694           | 15.94          |
| 8     | 1     | 472.9                 | 471.21             | 99.65     | 3.694           | 15.94          |
| 24    | 1     | 1418.6                | 1412.45            | 99.56     | 3.694           | 15.93          |
| 96    | 4     | 4513.7                | 4474.46            | 99.13     | 2.939           | 15.86          |
| 192   | 8     | 9411.6                | 9280.62            | 98.61     | 3.064           | 15.78          |

PState-2 (`cpupower` limited frequency)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 30.4                  | 30.20              | 99.50     | 1.897           | 15.92          |
| 8     | 1     | 242.8                 | 241.48             | 99.45     | 1.897           | 15.91          |
| 24    | 1     | 728.5                 | 724.00             | 99.38     | 1.897           | 15.90          |
| 96    | 4     | 2913.9                | 2891.34            | 99.22     | 1.897           | 15.88          |
| 192   | 8     | 5828.0                | 5766.76            | 98.95     | 1.897           | 15.83          |

### Double avx512 fma + add flops

Theoretical:

- cores × frequency × ((fma units × fma ops) × (512/64) + (add units × (256/64)))
- cores × frequency × (16 + 8) = cores × frequency × 24

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma_add -w M0:524288B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma_add -w M0:4194304B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma_add -w M0:12582912B:24
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma_add -w M0:12582912B:24 -w M1:12582912B:24 -w M2:12582912B:24 -w M3:12582912B:24
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma_add -w M0:12582912B:24 -w M1:12582912B:24 -w M2:12582912B:24 -w M3:12582912B:24 -w M4:12582912B:24 -w M5:12582912B:24 -w M6:12582912B:24 -w M7:12582912B:24
```

PState-3 (with boost)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 88.7                  | 88.28              | 99.56     | 3.694           | 23.90          |
| 8     | 1     | 709.3                 | 706.59             | 99.61     | 3.694           | 23.91          |
| 24    | 1     | 2051.0                | 2037.03            | 99.32     | 3.561           | 23.84          |
| 96    | 4     | 6395.8                | 6311.53            | 98.68     | 2.776           | 23.68          |
| 192   | 8     | 12782.5               | 12609.09           | 98.64     | 2.774           | 23.67          |

PState-2 (`cpupower` limited frequency)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 45.5                  | 45.26              | 99.44     | 1.897           | 23.86          |
| 8     | 1     | 364.2                 | 362.04             | 99.39     | 1.897           | 23.85          |
| 24    | 1     | 1092.7                | 1085.78            | 99.36     | 1.897           | 23.85          |
| 96    | 4     | 4371.0                | 4334.31            | 99.16     | 1.897           | 23.80          |
| 192   | 8     | 8741.7                | 8636.27            | 98.79     | 1.897           | 23.71          |

### Single avx512 fma flops:

Theoretical:

- cores × frequency × (fma units × fma ops) × (vector size / sp size)
- cores × frequency × (1 × 2) × (512/32) = cores × frequency × 32

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -w M0:524288B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -w M0:4194304B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -w M0:12582912B:24
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -w M0:12582912B:24 -w M1:12582912B:24 -w M2:12582912B:24 -w M3:12582912B:24
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -w M0:12582912B:24 -w M1:12582912B:24 -w M2:12582912B:24 -w M3:12582912B:24 -w M4:12582912B:24 -w M5:12582912B:24 -w M6:12582912B:24 -w M7:12582912B:24
```

PState-3 (with boost)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 118.2                 | 117.80             | 99.65     | 3.694           | 31.89          |
| 8     | 1     | 945.8                 | 942.25             | 99.63     | 3.694           | 31.88          |
| 24    | 1     | 2836.6                | 2824.93            | 99.59     | 3.693           | 31.87          |
| 96    | 4     | 9074.6                | 9002.22            | 99.20     | 2.954           | 31.74          |
| 192   | 8     | 18940.3               | 18667.85           | 98.56     | 3.083           | 31.54          |

PState-2 (`cpupower` limited frequency)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 60.7                  | 60.40              | 99.49     | 1.897           | 31.84          |
| 8     | 1     | 485.6                 | 483.04             | 99.48     | 1.897           | 31.83          |
| 24    | 1     | 1457.0                | 1448.31            | 99.40     | 1.897           | 31.81          |
| 96    | 4     | 5828.0                | 5784.78            | 99.26     | 1.897           | 31.76          |
| 192   | 8     | 11655.3               | 11550.48           | 99.10     | 1.897           | 31.71          |

### Single avx512 flops (non-fma kernel):

Theoretical:

- multiply on the 2 FMA-capable units + add on the 2 ADD-only units, running
  concurrently:
- cores × frequency × ((fma units × mul ops) × (vector size / sp size) + (add units × add ops) × (256 / sp size))
- cores × frequency × ((1 × 1) × (512/32) + (2 × 1) × (256/32)) = cores × frequency × (16 + 16) = cores × frequency × 32

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512 -w M0:524288B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512 -w M0:4194304B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512 -w M0:12582912B:24
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512 -w M0:12582912B:24 -w M1:12582912B:24 -w M2:12582912B:24 -w M3:12582912B:24
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512 -w M0:12582912B:24 -w M1:12582912B:24 -w M2:12582912B:24 -w M3:12582912B:24 -w M4:12582912B:24 -w M5:12582912B:24 -w M6:12582912B:24 -w M7:12582912B:24
```

PState-3 (with boost)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 118.2                 | 103.35             | 87.43     | 3.694           | 27.98          |
| 8     | 1     | 945.8                 | 830.78             | 87.84     | 3.694           | 28.11          |
| 24    | 1     | 2837.2                | 2489.16            | 87.73     | 3.694           | 28.07          |
| 96    | 4     | 7780.0                | 6828.40            | 87.77     | 2.533           | 28.09          |
| 192   | 8     | 16350.2               | 14219.94           | 86.97     | 2.661           | 27.83          |

PState-2 (`cpupower` limited frequency)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 60.7                  | 53.16              | 87.57     | 1.897           | 28.02          |
| 8     | 1     | 485.7                 | 425.58             | 87.63     | 1.897           | 28.04          |
| 24    | 1     | 1457.0                | 1275.88            | 87.57     | 1.897           | 28.02          |
| 96    | 4     | 5828.0                | 5094.57            | 87.42     | 1.897           | 27.97          |
| 192   | 8     | 11651.0               | 10192.82           | 87.48     | 1.896           | 27.99          |

One likely explanation for the ~88% of peak for the non-FMA kernel compared to
the ~99.6% for the pure-FMA kernel may be because each add depends on its own
multiply result.

### Single scalar flops:

Theoretical:

- cores × frequency × (fp pipes × 1 flop) = cores × frequency × 4

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_SP -m likwid-bench -t peakflops_sp -w M0:524288B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7 -g FLOPS_SP -m likwid-bench -t peakflops_sp -w M0:4194304B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_SP -m likwid-bench -t peakflops_sp -w M0:12582912B:24
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g FLOPS_SP -m likwid-bench -t peakflops_sp -w M0:12582912B:24 -w M1:12582912B:24 -w M2:12582912B:24 -w M3:12582912B:24
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g FLOPS_SP -m likwid-bench -t peakflops_sp -w M0:12582912B:24 -w M1:12582912B:24 -w M2:12582912B:24 -w M3:12582912B:24 -w M4:12582912B:24 -w M5:12582912B:24 -w M6:12582912B:24 -w M7:12582912B:24
```

PState-3 (with boost)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 14.8                  | 9.81               | 66.44     | 3.693           | 2.66           |
| 8     | 1     | 118.2                 | 78.45              | 66.36     | 3.694           | 2.65           |
| 24    | 1     | 354.7                 | 235.22             | 66.32     | 3.694           | 2.65           |
| 96    | 4     | 1191.5                | 787.80             | 66.12     | 3.103           | 2.64           |
| 192   | 8     | 2489.3                | 1633.31            | 65.61     | 3.241           | 2.62           |

PState-2 (`cpupower` limited frequency)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) | flops/cyc/core |
|-------|-------|-----------------------|--------------------|-----------|-----------------|----------------|
| 1     | 1     | 7.6                   | 5.03               | 66.31     | 1.897           | 2.65           |
| 8     | 1     | 60.7                  | 40.21              | 66.24     | 1.897           | 2.65           |
| 24    | 1     | 182.1                 | 120.40             | 66.11     | 1.897           | 2.64           |
| 96    | 4     | 728.5                 | 479.83             | 65.87     | 1.897           | 2.63           |
| 192   | 8     | 1457.0                | 960.49             | 65.92     | 1.897           | 2.64           |

### Memory bandwidth:

Theoretical:

- Per channel: DDR5-4800 → 4800 MT/s × 8 bytes = 38.4 GB/s
- Per NUMA domain (NPS=4): 3 channels × 38.4 GB/s = 115.2 GB/s

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0     -g MEM -m likwid-bench -t stream_mem_avx_fma -w M0:536870912B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7   -g MEM -m likwid-bench -t stream_mem_avx_fma -w M0:4294967296B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23  -g MEM -m likwid-bench -t stream_mem_avx_fma -w M0:12884901888B:24
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g MEM -m likwid-bench -t stream_mem_avx_fma -w M0:12884901888B:24 -w M1:12884901888B:24 -w M2:12884901888B:24 -w M3:12884901888B:24
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g MEM -m likwid-bench -t stream_mem_avx_fma -w M0:12884901888B:24 -w M1:12884901888B:24 -w M2:12884901888B:24 -w M3:12884901888B:24 -w M4:12884901888B:24 -w M5:12884901888B:24 -w M6:12884901888B:24 -w M7:12884901888B:24
```

PState-3 (with boost)
| Cores | CCDs | NUMAs | Theoretical (GB/s) | Measured (GB/s) | % of Peak | Read (GB/s) | Write (GB/s) |
|-------|------|-------|--------------------|-----------------|-----------|-------------|--------------|
| 1     | 1    | 1     | 115.2              | 45.74           | 39.71     | 30.50       | 15.25        |
| 8     | 1    | 1     | 115.2              | 48.72           | 42.29     | 32.50       | 16.22        |
| 24    | 3    | 1     | 115.2              | 93.50           | 81.16     | 62.35       | 31.15        |
| 96    | 12   | 4     | 460.8              | 373.18          | 80.99     | 248.81      | 124.37       |
| 192   | 24   | 8     | 921.6              | 745.06          | 80.84     | 496.78      | 248.29       |

PState-2 (`cpupower` limited frequency)
| Cores | CCDs | NUMAs | Theoretical (GB/s) | Measured (GB/s) | % of Peak | Read (GB/s) | Write (GB/s) |
|-------|------|-------|--------------------|-----------------|-----------|-------------|--------------|
| 1     | 1    | 1     | 115.2              | 42.16           | 36.60     | 28.11       | 14.05        |
| 8     | 1    | 1     | 115.2              | 46.19           | 40.10     | 30.82       | 15.37        |
| 24    | 3    | 1     | 115.2              | 93.17           | 80.88     | 62.14       | 31.03        |
| 96    | 12   | 4     | 460.8              | 371.47          | 80.61     | 247.67      | 123.80       |
| 192   | 24   | 8     | 921.6              | 741.93          | 80.50     | 494.68      | 247.24       |

### L2 bandwidth

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0     -g L2 -m likwid-bench -t load -w M0:4194304B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7   -g L2 -m likwid-bench -t load -w M0:33554432B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23  -g L2 -m likwid-bench -t load -w M0:100663296B:24
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g L2 -m likwid-bench -t load -w M0:100663296B:24 -w M1:100663296B:24 -w M2:100663296B:24 -w M3:100663296B:24
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g L2 -m likwid-bench -t load -w M0:100663296B:24 -w M1:100663296B:24 -w M2:100663296B:24 -w M3:100663296B:24 -w M4:100663296B:24 -w M5:100663296B:24 -w M6:100663296B:24 -w M7:100663296B:24
```

PState-3 (with boost)
| Cores | CCDs | NUMAs | Per core (GB/s) | Aggregate (GB/s) | Frequency (GHz) | Per core / Frequency (GB/s/GHz) |
|-------|------|-------|-----------------|------------------|-----------------|---------------------------------|
| 1     | 1    | 1     | 57.61           | 57.61            | 3.693           | 15.60                           |
| 8     | 1    | 1     | 56.74           | 453.94           | 3.694           | 15.36                           |
| 24    | 3    | 1     | 55.84           | 1340.12          | 3.647           | 15.31                           |
| 96    | 12   | 4     | 35.29           | 3387.40          | 2.355           | 14.98                           |
| 192   | 24   | 8     | 35.86           | 6885.80          | 2.531           | 14.17                           |

PState-2 (`cpupower` limited frequency)
| Cores | CCDs | NUMAs | Per core (GB/s) | Aggregate (GB/s) | Frequency (GHz) | Per core / Frequency (GB/s/GHz) |
|-------|------|-------|-----------------|------------------|-----------------|---------------------------------|
| 1     | 1    | 1     | 29.38           | 29.38            | 1.897           | 15.49                           |
| 8     | 1    | 1     | 29.61           | 236.86           | 1.897           | 15.61                           |
| 24    | 3    | 1     | 29.33           | 703.86           | 1.897           | 15.46                           |
| 96    | 12   | 4     | 29.08           | 2792.02          | 1.897           | 15.33                           |
| 192   | 24   | 8     | 28.85           | 5539.17          | 1.897           | 15.21                           |

### L2 bandwidth (load_avx, 256-bit)

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0     -g L2 -m likwid-bench -t load_avx -w M0:4194304B:1
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-7   -g L2 -m likwid-bench -t load_avx -w M0:33554432B:8
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23  -g L2 -m likwid-bench -t load_avx -w M0:100663296B:24
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g L2 -m likwid-bench -t load_avx -w M0:100663296B:24 -w M1:100663296B:24 -w M2:100663296B:24 -w M3:100663296B:24
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g L2 -m likwid-bench -t load_avx -w M0:100663296B:24 -w M1:100663296B:24 -w M2:100663296B:24 -w M3:100663296B:24 -w M4:100663296B:24 -w M5:100663296B:24 -w M6:100663296B:24 -w M7:100663296B:24
```

PState-3 (with boost)
| Cores | CCDs | NUMAs | Per core (GB/s) | Aggregate (GB/s) | Frequency (GHz) | Per core / Frequency (GB/s/GHz) |
|-------|------|-------|-----------------|------------------|-----------------|---------------------------------|
| 1     | 1    | 1     | 89.86           | 89.86            | 3.694           | 24.32                           |
| 8     | 1    | 1     | 77.36           | 618.86           | 3.694           | 20.94                           |
| 24    | 3    | 1     | 72.17           | 1732.03          | 3.411           | 21.16                           |
| 96    | 12   | 4     | 46.23           | 4438.55          | 2.275           | 20.32                           |
| 192   | 24   | 8     | 47.99           | 9213.33          | 2.440           | 19.67                           |

PState-2 (`cpupower` limited frequency)
| Cores | CCDs | NUMAs | Per core (GB/s) | Aggregate (GB/s) | Frequency (GHz) | Per core / Frequency (GB/s/GHz) |
|-------|------|-------|-----------------|------------------|-----------------|---------------------------------|
| 1     | 1    | 1     | -               | -                | -               | -                               |
| 8     | 1    | 1     | -               | -                | -               | -                               |
| 24    | 3    | 1     | -               | -                | -               | -                               |
| 96    | 12   | 4     | -               | -                | -               | -                               |
| 192   | 24   | 8     | -               | -                | -               | -                               |

Note: load_avx512 was also run and produces virtually identical L2 bandwidth,
which is expected since Zen4's L1<->L2 datapath width does not increase for
512-bit accesses (same 2x256-bit tandem execution as AVX-512 FMA, see above).
