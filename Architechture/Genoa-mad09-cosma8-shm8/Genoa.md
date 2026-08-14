## Technical specifications:

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
- AVX512 (512-bit) on Zen4 provides 1 FMA units/core

## Peaks

### Double avx512 fma flops

Theoretical:

- cores × frequency × (fma units × fma ops) × (vector size / dp size)
- cores × frequency × (1 × 2) × (512/64) = cores × frequency × 16

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -W N:12MB:24 -i 1000
```

PState-3 (with boost)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) |
|-------|-------|-----------------------|--------------------|-----------|-----------------|
| 24    | 1     | 1420.8                | 1413.1             | 99.46     | 3.7             |
| 96    | 4     | 5683.2                | 5634.6             | 99.14     | 3.7             |
| 192   | 8     | 11366.4               | 11216.8            | 98.68     | 3.7             |

PState-2 (`cpupower` limited frequency)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) |
|-------|-------|-----------------------|--------------------|-----------|-----------------|
| 24    | 1     | 729.6                 | 722.3              | 99.00     | 1.9             |
| 96    | 4     | 2918.4                | 2871.3             | 98.39     | 1.9             |
| 192   | 8     | 5836.8                | 5732.4             | 98.21     | 1.9             |

### Single avx512 fma flops:

Theoretical:

- cores × frequency × (fma units × fma ops) × (vector size / sp size)
- cores × frequency × (1 × 2) × (512/32) = cores × frequency × 32

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -W N:12MB:24 -i 1000
```

PState-3 (with boost)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) |
|-------|-------|-----------------------|--------------------|-----------|-----------------|
| 24    | 1     | 2841.6                | 2827.1             | 99.49     | 3.7             |
| 96    | 4     | 11366.4               | 11287.4            | 99.30     | 3.7             |
| 192   | 8     | 22732.8               | 22344.3            | 98.29     | 3.7             |

PState-2 (`cpupower` limited frequency)
| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) |
|-------|-------|-----------------------|--------------------|-----------|-----------------|
| 24    | 1     | 1459.2                | 1446.6             | 99.14     | 1.9             |
| 96    | 4     | 5836.8                | 5783.1             | 99.08     | 1.9             |
| 192   | 8     | 11673.6               | 11543.2            | 98.88     | 1.9             |

### Memory bandwidth:

Theoretical:

- Per channel: DDR5-4800 → 4800 MT/s × 8 bytes = 38.4 GB/s
- Per NUMA domain: 3 channels × 38.4 GB/s = 115.2 GB/s

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g MEMREAD -m likwid-bench -t stream_mem_avx_fma -W N:12GB:24 -i 50
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g MEMWRITE -m likwid-bench -t stream_mem_avx_fma -W N:12GB:24 -i 50
```

Note that for the memory bandwidth, `likwid-perfctr` was called twice with read
and write, then the values summed. The values from `likwid-bench` itself were very
similar (within 1% difference), so those could be used directly without invoking
`likwid-perfctr`. The benchmarks were also run with a fixed clock speed and, as
expected, the CPU clocks make no noticeable difference, particularly on a single
NUMA domain. 

| Cores | NUMAs | Theoretical (GB/s) | Measured  (GB/s) | % of Peak |
|-------|-------|--------------------|------------------|-----------|
| 24    | 1     | 115.2              | 91.8             | 79.69     |
| 96    | 4     | 460.8              | 366.4            | 79.51     |
| 192   | 8     | 921.6              | 731.0            | 79.32     |

### L2 bandwidth

Likwid command (scaled for number of cores):

``` bash
  numactl --cpunodebind=0 --membind=0 likwid-pin -c 0-23 likwid-perfctr -C 0-23 -g L2 -m -- likwid-bench -t load -W S0:25165824B:24 -i 50000
```

| Frequency | Core    | NUMA        |
|-----------|---------|-------------|
| 3.7 GHz   | 57 GB/s | 1312.0 GB/s |
| 1.9 GHz   | -       | 674.0 GB/s  |

Notes:

- Likwid gives 57 GB/s per-core and 1312 GB/s for a NUMA domain at 3.7GHz.  Using 1312 / 24 to scale down to 1 core gives 54.7 GB/s, which is close enough to be in agreement.
- Scaling 1312 by the frequency ratio to (1.9/3.7) gives 674 GB/s, which is in good agreement with the likwid result.
