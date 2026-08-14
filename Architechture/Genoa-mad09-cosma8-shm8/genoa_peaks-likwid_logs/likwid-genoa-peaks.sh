# DP FLOP/s (no AVX or FMA) - FLOPS_SP is used, but on Genoa (Zen4) FLOPS_DP and FLOPS_SP so either can be used.
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_DP -m likwid-bench -t peakflops -W N:12MB:24 -i 5000 2>&1 | tee genoa_flops_dp_24c.log
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g FLOPS_DP -m likwid-bench -t peakflops -W N:48MB:96 -i 5000 2>&1 | tee genoa_flops_dp_96c.log
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g FLOPS_DP -m likwid-bench -t peakflops -W N:96MB:192 -i 5000 2>&1 | tee genoa_flops_dp_192c.log

# SP FLOP/s (no AVX or FMA) - FLOPS_SP is used, but on Genoa (Zen4) FLOPS_DP and FLOPS_SP so either can be used.
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_SP -m likwid-bench -t peakflops_sp -W N:12MB:24 -i 5000 2>&1 | tee genoa_flops_sp_24c.log
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g FLOPS_SP -m likwid-bench -t peakflops_sp -W N:48MB:96 -i 5000 2>&1 | tee genoa_flops_sp_96c.log
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g FLOPS_SP -m likwid-bench -t peakflops_sp -W N:96MB:192 -i 5000 2>&1 | tee genoa_flops_sp_192c.log

# DP FLOP/s (with AVX512 and FMA) - FLOPS_DP is used, but on Genoa (Zen4) FLOPS_DP and FLOPS_SP so either can be used.
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -W N:12MB:24 -i 5000 2>&1 | tee genoa_flops_dp_avx512_fma_24c.log
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -W N:48MB:96 -i 5000 2>&1 | tee genoa_flops_dp_avx512_fma_96c.log
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g FLOPS_DP -m likwid-bench -t peakflops_avx512_fma -W N:96MB:192 -i 5000 2>&1 | tee genoa_flops_dp_avx512_fma_192c.log

# SP FLOP/s (with AVX512 and FMA) - FLOPS_SP is used, but on Genoa (Zen4) FLOPS_DP and FLOPS_SP so either can be used.
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -W N:12MB:24 -i 5000 2>&1 | tee genoa_flops_sp_avx512_fma_24c.log
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -W N:48MB:96 -i 5000 2>&1 | tee genoa_flops_sp_avx512_fma_96c.log
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g FLOPS_SP -m likwid-bench -t peakflops_sp_avx512_fma -W N:96MB:192 -i 5000 2>&1 | tee genoa_flops_sp_avx512_fma_192c.log

# Memory Reads (stream memory with AVX and FMA for consistancy) - MEMREAD on Genoa (Zen4) is separate from MEMWRITE so both have to be ran and summed.
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g MEMREAD -m likwid-bench -t stream_mem_avx_fma -W N:12GB:24 -i 50 2>&1 | tee genoa_memread_24c.log
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g MEMREAD -m likwid-bench -t stream_mem_avx_fma -W N:48GB:96 -i 50 2>&1 | tee genoa_memread_96c.log
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g MEMREAD -m likwid-bench -t stream_mem_avx_fma -W N:96GB:192 -i 50 2>&1 | tee genoa_memread_192c.log

# Memory Writes (stream memory with AVX and FMA for consistancy) - MEMWRITE on Genoa (Zen4) is separate from MEMREAD so both have to be ran and summed.
numactl --cpunodebind=0 --membind=0 likwid-perfctr -C 0-23 -g MEMWRITE -m likwid-bench -t stream_mem_avx_fma -W N:12GB:24 -i 50 2>&1 | tee genoa_memwrite_24c.log
numactl --cpunodebind=0-3 --membind=0-3 likwid-perfctr -C 0-95 -g MEMWRITE -m likwid-bench -t stream_mem_avx_fma -W N:48GB:96 -i 50 2>&1 | tee genoa_memwrite_96c.log
numactl --cpunodebind=0-7 --membind=0-7 likwid-perfctr -C 0-191 -g MEMWRITE -m likwid-bench -t stream_mem_avx_fma -W N:96GB:192 -i 50 2>&1 | tee genoa_memwrite_192c.log

# L2 cache (load from memory) - L2 on Genoa (Zen4) measures the memory bandwidth from L2 -> CPU; data size used exactly to fill L2 cache of 3 CCDs (1 NUMA domain).
numactl --cpunodebind=0 --membind=0 likwid-pin -c 0-23 likwid-perfctr -C 0-23 -g L2 -m likwid-bench -t load -W S0:25165824B:24 -i 50000 2>&1 | tee genoa_l2_24c.log

