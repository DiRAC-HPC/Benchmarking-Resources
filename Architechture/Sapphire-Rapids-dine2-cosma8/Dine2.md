# **Intel Intel(R) Xeon(R) Gold 6430 (dine2) on Cosma8**

## **Technical specifications:**

| Component | Per-Core | Per-Tile (8 cores) | Per-Socket (4 tiles) | Node (2 Sockets) |
| ----- | ----- | ----- | ----- | ----- |
| Cores | 1 | 8 | 32 | 64 |
| L1d Cache | 48 KB | 384 KB | 1536 KB or 1.5 MB | 3072 KB or 3 MB |
| L1i Cache | 32 KB | 256 KB | 1024 KB or 1 MB | 2048 KB or 2 MB |
| L2 Cache | 2 MB | 16 MB | 64 MB | 128 MB |
| L3 Cache | 960 KB | 7.5 MB | 60 MB | 120 MB |
| Memory Channels (DDR5-4400) | 0.25 channel | 2 channels | 8 channels | 16 channels |
| NUMA Domains (w/o SNC4) | — | — | 1 NUMA domain | 2 NUMA domains |
| Topology Mapping | — | 1 compute tile | 4 tiles total | 8 tiles total |

Notes:

* Base and boost clocks  
  * Base clock: 2.1 GHz  
  * Max turbo: up to 3.5 GHz  
* The CPU is composed of 4 compute tiles (each tile \= 8 cores \+ 7.5 MB shared L3/LLC).  
* Each tile is effectively its own NUMA domain when Sub-NUMA Clustering (SNC4) is enabled.  
  * Not enabled on Cosma.  
* L3 cache is segmented and distributed across tiles; it is not fully unified across the socket.  
* Each socket provides 8 DDR5-4400 channels via integrated memory controllers (2 per tile).  
  * Memory latency and bandwidth vary slightly by NUMA locality due to tile-to-memory affinity.  
* Each tile forms a coherent domain with its L3 cache slice and 2 memory channels, minimizing cross-tile latency.

## **Peaks**

### **Double avx512 fma flops**

Theoretical:

* cores × frequency × (fma units × fma ops) × (vector size / dp size)  
* cores × frequency × (2 × 2\) × (512/64)  
* cores × frequency × 4 x 8  
* cores × frequency × 32

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_AVX -m likwid-bench -t peakflops_avx512_fma -W N:32KB:1
```

| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) |
| ----- | ----- | ----- | ----- | ----- | ----- |
| 1 | 1 | 76.8 | 76.375 | 99.45 | 2.4 |
| 8 | 1 | 614.4 | 604.718 | 98.42 | 2.4 |
| 16 | 1 | 1228.8 | 1208.024 | 98.31 | 2.4 |
| 32 | 1 | 2457.6 | 2339.459 | 95.19 | 2.4 |
| 64 | 2 | 4915.2 | 4655.628 | 94.72 | 2.4 |

### **Single avx512 fma flops:**

Theoretical:

* cores × frequency × (fma units × fma ops) × (vector size / sp size)  
* cores × frequency × (2 × 2\) × (512/32)  
* cores × frequency × 4 x 16  
* cores × frequency × 64

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g FLOPS_AVX -m likwid-bench -t peakflops_sp_avx512_fma -W N:32KB:1
```

| Cores | NUMAs | Theoretical (GFLOP/s) | Measured (GFLOP/s) | % of Peak | Frequency (GHz) |
| ----- | ----- | ----- | ----- | ----- | ----- |
| 1 | 1 | 153.6 | 152.754 | 99.45 | 2.4 |
| 8 | 1 | 1228.8 | 1218.754 | 99.18 | 2.4 |
| 16 | 1 | 2457.6 | 2414.631 | 98.25 | 2.4 |
| 32 | 1 | 4915.2 | 4691.886 | 95.46 | 2.4 |
| 64 | 2 | 9830.4 | 9271.505 | 94.31 | 2.4 |

### **Memory bandwidth:**

Theoretical:

* Per channel: DDR5-4400 → 4400 MT/s × 8 bytes \= 35.2 GB/s  
* Per NUMA domain: 8 channels × 35.2 GB/s \= 281.6 GB/s

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g MEM -m likwid-bench -t stream_mem_avx512 -W N:2048MB:1
```

| Cores | Channels | Theoretical (GB/s) | Measured (GB/s) | % of Peak |
| ----- | ----- | ----- | ----- | ----- |
| 1 | 1 | 35.20 | 20.090 | 57.07 |
| 2 | 1 | 35.20 | 37.267 | 105.87 |
| 3 | 1 | 35.20 | 55.309 | 157.13 |
| 4 | 1 | 35.20 | 72.388 | 205.65 |
| 8 | 2 | 70.40 | 123.667 | 175.66 |
| 12 | 3 | 105.60 | 153.667 | 145.52 |
| 16 | 4 | 140.80 | 170.889 | 121.37 |
| 20 | 5 | 176.00 | 179.476 | 101.97 |
| 24 | 6 | 211.20 | 184.048 | 87.14 |
| 28 | 7 | 246.40 | 187.114 | 75.94 |
| 32 | 8 | 281.60 | 189.111 | 67.16 |
| 64 | 16 | 563.20 | 376.794 | 66.90 |

### **L2 bandwidth**

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g L2 -m likwid-bench -t load_avx512 -W S0:2048KB:1
```

| Cores | NUMAs | Measured (GB/s) | Frequency (GHz) |
| ----- | ----- | ----- | ----- |
| 1 | 1 | 52.073 | 2.4 |
| 8 | 1 | 541.455 | 2.4 |
| 16 | 1 | 994.649 | 2.4 |
| 32 | 1 | 2166.650 | 2.4 |
| 64 | 2 | 2169.896 | 2.4 |

### **L3 bandwidth**

Likwid command (scaled for number of cores):

``` bash
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0 -g L3 -m likwid-bench -t load_avx512 -W S0:61440KB:1
```

| Cores | NUMAs | Measured (GB/s) | Frequency (GHz) |
| ----- | ----- | ----- | ----- |
| 1 | 1 | 50.037 | 2.4 |
| 8 | 1 | 208.198 | 2.4 |
| 16 | 1 | 332.295 | 2.4 |
| 32 | 1 | 431.218 | 2.4 |
| 64 | 2 | 428.011 | 2.4 |

