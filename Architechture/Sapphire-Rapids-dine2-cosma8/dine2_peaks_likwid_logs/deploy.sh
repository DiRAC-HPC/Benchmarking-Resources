#!/bin/bash

########################################################################
# Deploy (compile, run/debug/profile, verify) the computation intensive 
# apps w.r.t. different platforms, compilers versions and configurations
########################################################################
function usage()
{
  echo "  Usage, example:                                                            "
  echo "  > ./deploy.sh likwid platform procs config testcase >& test.log &          "
  echo "  action: compile or reference                                               "
  echo "                                                                             "
  echo "  likdwid: lkd (one can choose any string)                                   "
  echo "  platform: cosma8-[dine2]-[intel]                                           "
  echo "  procs: [seq|p]-t                                                           "
  echo "    p: seq or no. of procs                                                   "
  echo "    t: no. of threads                                                        "
  echo "  config: n[1|2]-lwpcFD-lwb-[0032+pda5f|2048+sdma50]                         "
  echo "  testcase: any reasonable id to record experiment/test                      "
  echo "                                                                             "
  echo "                                                                             "
  echo " > ./deploly.sh chk [std|adv]                                                "
  echo "                                                                             "
}

function chk()
{
  typ=$1
  key=$2
  fmt_data="%90s %10s %10s %10s %10s %s %s %s %s %s %s\n"
  printf "$fmt_data" LOG_NAME SETUP\(SEC\) BUILD\(SEC\) RUN\(SEC\) NODES MISCELLANEOUS
  for l in $(ls -1 *$key*.log); do
    if grep "tS=" $l >& /dev/null; then
      tS=$(grep "tS=" $l | tail -n 1 | cut -d '=' -f 2)
    else
      tS="NA"
    fi
    if grep "tb=" $l >& /dev/null; then
      tb=$(grep "tb=" $l | tail -n 1 | cut -d '=' -f 2)
    else
      tb="NA"
    fi
    if grep "tr=" $l >& /dev/null; then
      tr=$(grep "tr=" $l | tail -n 1 | cut -d '=' -f 2)
    else
      tr="NA"
    fi
    if grep "SLURM_JOB_NODELIST" $l >& /dev/null; then
      n=$(grep "SLURM_JOB_NODELIST" $l | cut -d '=' -f 2)
    else
      n=$(grep "HOSTNAME" $l | cut -d '=' -f 2)
    fi
    
    misl="NA" # sum=3, min=4, max=5, avg=6
    case $typ in
      std)
        if grep "Cycles:" $l >& /dev/null; then
           rt=$(grep -A21 "Cycles:" $l | xargs | awk '{print $10}')
           cl=$(grep -A21 "Cycles:" $l | xargs | awk '{print $5}')
           fl=$(grep -A21 "Cycles:" $l | xargs | awk '{print $34}')
          mw2=$(grep -A21 "Cycles:" $l | xargs | awk '{print $38}')
          mw1=$(grep -A21 "Cycles:" $l | xargs | awk '{print $40}')
          misl="RT(s)=$rt C(Hz)=$cl MFLOP/s=$fl BW(MB/s)u=$mw1 DV(B)=$mw2"
        fi
        ;;
      adv)
        if grep "Runtime (RDTSC) \[s\] STAT" $l >& /dev/null; then
          rt=$(grep "Runtime (RDTSC) \[s\] STAT" $l | cut -d '|' -f 5 | xargs)
        else
          rt=$(grep "Runtime (RDTSC) \[s\]" $l | cut -d '|' -f 3 | xargs)
        fi
        if grep "Clock \[MHz\] STAT" $l >& /dev/null; then
          cl=$(grep "Clock \[MHz\] STAT" $l         | cut -d '|' -f 6 | xargs)
        else
          cl=$(grep "Clock \[MHz\]" $l         | cut -d '|' -f 3 | xargs)
        fi 
        if grep "CPI STAT" $l >& /dev/null; then
          cp=$(grep "CPI STAT" $l         | cut -d '|' -f 6 | xargs)
        else
          cp=$(grep "     CPI     " $l         | cut -d '|' -f 3 | xargs)
        fi 
        mc="RT(s)-Ma=$rt C(MHz)-Av=$cl CPI-Av=$cp"
        case $l in
          *FA*) 
            if grep "\[MFLOP\/s\] STAT" $l >& /dev/null; then
              fa=$(grep "\[MFLOP\/s\] STAT" $l | cut -d '|' -f 3 | xargs)
            else
              fa=$(grep "\[MFLOP\/s\]" $l | cut -d '|' -f 3 | xargs)
            fi
            misl="$mc MFLOP/s-Su=$fa"
            ;;
          *FD*) 
            if grep "\[MFLOP\/s\] STAT" $l >& /dev/null; then
              fd=$(grep "\[MFLOP\/s\] STAT" $l | cut -d '|' -f 3 | xargs)
            else
              fd=$(grep "\[MFLOP\/s\]" $l | cut -d '|' -f 3 | xargs)
            fi
            misl="$mc MFLOP/s-Su=$fd"
            ;;
          *FS*)
            if grep "\[MFLOP\/s\] STAT" $l >& /dev/null; then
              fs=$(grep "\[MFLOP\/s\] STAT" $l | cut -d '|' -f 3 | xargs)
            else
              fs=$(grep "\[MFLOP\/s\]" $l | cut -d '|' -f 3 | xargs)
            fi
            misl="$mc MFLOP/s-Su=$fs"
            ;;
          *MM*)
            if grep "Memory bandwidth \[MBytes\/s\] STAT" $l $l >& /dev/null; then
              mm1=$(grep "Memory bandwidth \[MBytes\/s\] STAT" $l | cut -d '|' -f 3 | xargs)
              mm2=$(grep "Memory data volume \[GBytes\] STAT" $l  | cut -d '|' -f 3 | xargs)
            else
              mm1=$(grep "Memory bandwidth \[MBytes\/s\]" $l | cut -d '|' -f 3 | xargs)
              mm2=$(grep "Memory data volume \[GBytes\]" $l  | cut -d '|' -f 3 | xargs)
            fi
            misl="$mc BW(MB/s)-Su=$mm1 DV(GB)-Su=$mm2"
            ;;
          *M1*)
            m11=$(grep "Memory bandwidth" $l | grep "\[MBytes\/s] STAT" | cut -d '|' -f 3 | xargs)
            m12=$(grep "Memory data volume" $l | grep "\[GBytes\] STAT" | cut -d '|' -f 3 | xargs)
            misl="$mc BW(MB/s)-Su=$m11 DV(GB)-Su=$m12"
            ;;
          *M2*)
            m21=$(grep "Memory bandwidth" $l | grep "\[MBytes\/s] STAT" | cut -d '|' -f 3 | xargs)
            m22=$(grep "Memory data volume" $l | grep "\[GBytes\] STAT" | cut -d '|' -f 3 | xargs)
            misl="$mc BW(MB/s)-Su=$m21 DV(GB)-Su=$m22"
            ;;
          *L2*)
            if grep "L2 bandwidth" $l >& /dev/null; then
              if grep "L2 bandwidth \[MBytes\/s\] STAT" $l >& /dev/null; then
                l21=$(grep "L2 bandwidth \[MBytes\/s\] STAT" $l | cut -d '|' -f 3 | xargs)
                l22=$(grep "L2 data volume \[GBytes\] STAT" $l  | cut -d '|' -f 3 | xargs)
              else
                l21=$(grep "L2 bandwidth \[MBytes\/s\]" $l | cut -d '|' -f 3 | xargs)
                l22=$(grep "L2 data volume \[GBytes\]" $l  | cut -d '|' -f 3 | xargs)
              fi
            else
              if grep "L2D load bandwidth \[MBytes\/s\] STAT" $l >& /dev/null; then
                l21=$(grep "L2D load bandwidth \[MBytes\/s\] STAT" $l | cut -d '|' -f 3 | xargs)
                l22=$(grep "L2D load data volume \[GBytes\] STAT" $l  | cut -d '|' -f 3 | xargs)
              else
                l21=$(grep "L2D load bandwidth \[MBytes\/s\]" $l | cut -d '|' -f 3 | xargs)
                l22=$(grep "L2D load data volume \[GBytes\]" $l  | cut -d '|' -f 3 | xargs)
              fi
            fi
            misl="$mc BW(MB/s)-Su=$l21 DV(GB)-Su=$l22"
            ;;
          *L3*)
            if grep "L3 bandwidth \[MBytes\/s\] STAT" $l >& /dev/null; then
              l31=$(grep "L3 bandwidth \[MBytes\/s\] STAT" $l | cut -d '|' -f 3 | xargs)
              l32=$(grep "L3 data volume \[GBytes\] STAT" $l  | cut -d '|' -f 3 | xargs)
            else
              l31=$(grep "L3 bandwidth \[MBytes\/s\]" $l | cut -d '|' -f 3 | xargs)
              l32=$(grep "L3 data volume \[GBytes\]" $l  | cut -d '|' -f 3 | xargs)
            fi
            misl="$mc BW(MB/s)-Su=$l31 DV(GB)-Su=$l32"
            ;;
          *CA*)
            if grep "data cache miss ratio STAT" $l >& /dev/null; then
              ca1=$(grep "data cache miss ratio STAT" $l | cut -d '|' -f 6 | xargs)
              ca2=$(grep "data cache misses STAT" $l     | cut -d '|' -f 3 | xargs)
            else
              ca1=$(grep "data cache miss ratio" $l | cut -d '|' -f 3 | xargs)
              ca2=$(grep "data cache misses" $l     | cut -d '|' -f 3 | xargs)
            fi
            misl="$mc DCMr-Av=$ca1 DCM-Su=$ca2"
            ;;
          *LA*)
            if grep "L2 miss ratio STAT" $l >& /dev/null; then
              la1=$(grep "L2 miss ratio STAT" $l | cut -d '|' -f 6 | xargs)
              la2=$(grep "L2 miss rate STAT" $l  | cut -d '|' -f 6 | xargs)
            else
              la1=$(grep "L2 miss ratio" $l | cut -d '|' -f 3 | xargs)
              la2=$(grep "L2 miss rate" $l  | cut -d '|' -f 3 | xargs)
            fi
            misl="$mc Mri-Av=$la1 Mre-Av=$la2"
            ;;
          *LB*)
            if grep "L3 miss ratio STAT" $l >& /dev/null; then
              lb1=$(grep "L3 miss ratio STAT" $l | cut -d '|' -f 6 | xargs)
              lb2=$(grep "L3 miss rate STAT" $l  | cut -d '|' -f 6 | xargs)
            else
              lb1=$(grep "L3 miss ratio" $l | cut -d '|' -f 3 | xargs)
              lb2=$(grep "L3 miss rate" $l  | cut -d '|' -f 3 | xargs)
            fi
            misl="$mc Mri-Av=$lb1 Mre-Av=$lb2"
            ;;
          *MR*)
            if grep "Memory read bandwidth \[MBytes\/s\] STAT" $l >& /dev/null; then
              mr1=$(grep "Memory read bandwidth \[MBytes\/s\] STAT" $l | cut -d '|' -f 3 | xargs)
              mr2=$(grep "Memory read data volume \[GBytes\] STAT" $l  | cut -d '|' -f 3 | xargs)
            else
              mr1=$(grep "Memory read bandwidth \[MBytes\/s\]" $l | cut -d '|' -f 3 | xargs)
              mr2=$(grep "Memory read data volume \[GBytes\]" $l  | cut -d '|' -f 3 | xargs)
            fi
            misl="$mc BW(MB/s)-Su=$mr1 DV(GB)-Su=$mr2"
            ;;
          *MW*)
            if grep "Memory write bandwidth \[MBytes\/s\] STAT" $l >& /dev/null; then
              mw1=$(grep "Memory write bandwidth \[MBytes\/s\] STAT" $l | cut -d '|' -f 3 | xargs)
              mw2=$(grep "Memory write data volume \[GBytes\] STAT" $l  | cut -d '|' -f 3 | xargs)
            else
              mw1=$(grep "Memory write bandwidth \[MBytes\/s\]" $l | cut -d '|' -f 3 | xargs)
              mw2=$(grep "Memory write data volume \[GBytes\]" $l  | cut -d '|' -f 3 | xargs)
            fi
            misl="$mc BW(MB/s)-Su=$mw1 DV(GB)-Su=$mw2"
            ;;
        esac
        ;;
        *) echo "Error: $typ not defined yet"; exit 1
      ;;
    esac
    printf "$fmt_data" $l $tS $tb $tr $n $misl
  done
  exit 0
}

## Common
if [[ $# -ne 5 ]]; then
  if [[ $1 == "chk" ]]; then
    chk $2 $3
  else 
    echo -e " \n  Please supply the correct number of arguments."
    usage; echo "Exiting."; exit 1
  fi
fi

# Download
date
#mkdir -p sources; cd sources
#if [[ ! -d  SWIFT ]]; then
#  git clone git@github.com:SWIFTSIM/SWIFT.git
#fi
#cd -

## Setup
ts=$(date +%s)
framework="$1"
platform="$2"
procs="$3"
config="$4"
testcase="$5"

machine=$(echo $platform | cut -d '-' -f 1)
partition=$(echo $platform | cut -d '-' -f 2)
compiler=$(echo $platform | cut -d '-' -f 3)

run_procs=$(echo $procs | cut -d '-' -f 1)
run_threads=$(echo $procs | cut -d '-' -f 2)

num=$(echo $config | cut -d '-' -f 1)
app=$(echo $config | cut -d '-' -f 2)
mod=$(echo $config | cut -d '-' -f 3)
ker=$(echo $config | cut -d '-' -f 4)

# Deal with platform
expid=$(basename $(pwd))
cd ..; project=$(pwd); cd -
lscpu
free -m
numactl --hardware
numastat
uptime
nvidia-smi

if [[ $platform == "cosma8-dine2-intel" ]]; then
  module load cosma/2024
  module load intel_comp/2025.0.1
  module load compiler-rt/latest
  module load tbb/latest
  module load umf/latest
  module load compiler/latest
  module load mpi/latest
  module load parmetis/4.0.3-64bit
  module load fftw/3.3.10
  module load gsl/2.8
  module load python/3.12.4
  module load ucx/1.17.0
  #module load hdf5/1.14.4
  module load parallel_hdf5/1.14.4
  module load likwid/5.4.1
  export OMP_NUM_THREADS=$run_threads
  case $run_threads in
    1) cnb="0"; mb="0"
       CV="0" ;;
    2) cnb="0"; mb="0"
       #CV="0,2" ;;
       CV="0-1" ;;
    3) cnb="0"; mb="0"
       #CV="0,2,4" ;;
       CV="0-2" ;;
    4) cnb="0"; mb="0"
       #CV="0,2,4,6" ;;
       CV="0-3" ;;
    8) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14" ;;
       CV="0-7" ;;
   12) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22" ;;
       CV="0-11" ;;
   16) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30" ;;
       CV="0-15" ;;
   18) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34" ;;
       CV="0-17" ;;
   20) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38" ;;
       CV="0-19" ;;
   22) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42" ;;
       CV="0-21" ;;
   24) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46" ;;
       CV="0-23" ;;
   26) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50" ;;
       CV="0-25" ;;
   28) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54" ;;
       CV="0-27" ;;
   30) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58" ;;
       CV="0-29" ;;
   32) cnb="0"; mb="0"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62" ;;
       CV="0-31" ;;
   64) cnb="0-1"; mb="0-1"
       #CV="0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62,1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,51,53,55,57,59,61,63" ;;
       CV="0-63" ;;
    *) echo "Error: Dine2's cnb, mb, CV not defined yet"; exit 1 ;;
  esac
  #sudo cpupower frequency-set -d 2100MHz
  #sudo cpupower frequency-set -u 2100MHz
  #sudo cpupower frequency-set -f 2100MHz
  sudo cpupower frequency-set -d 2400MHz
  sudo cpupower frequency-set -u 2400MHz
  sudo cpupower frequency-set -f 2400MHz
  #sudo cpupower frequency-set -d 3000MHz
  #sudo cpupower frequency-set -u 3000MHz
  #sudo cpupower frequency-set -f 3000MHz
  sudo cpupower frequency-info
else
  echo "Error: $platform not defined yet"; exit 1
fi
module list
env
which gcc; gcc -v

# Deal with work directory
set -xuve
if [[ $run_procs == "seq" ]]; then
  procs=${run_procs}-$(printf "%03d" $run_threads)
else
  procs=$(printf "%03d" $run_procs)-$(printf "%03d" $run_threads)
fi
work="${framework}_${platform}_${procs}_${config}_${testcase}"
mkdir -p $work; cd $work
te=$(date +%s)
tS=$((te-ts))

## Compile
ts=$(date +%s)

## Config
likwid-powermeter -i
likwid-topology
likwid-perfctr -a
likwid-bench -a

part0=""; part1=""; part2=""; part3=""; part4=""

case $num in
  n1) part0="numactl --cpunodebind=$cnb --membind=$mb" ;;
  n2) part0="numactl --cpunodebind=$cnb --membind=$mb" likwid-pin -c $CV ;;
esac

case $app in
  lwpc*) 
    case $app in
      *FA*) group="FLOPS_AVX" ;;
      *FS*) group="FLOPS_SP" ;;
      *FD*) group="FLOPS_DP" ;;
      *MM*) group="MEM" ;;
      *M1*) group="MEM1" ;;
      *M2*) group="MEM2" ;;
      *L2*) group="L2" ;;
      *L3*) group="L3" ;;
      *CA*) group="CACHE" ;;
      *LA*) group="L2CACHE" ;;
      *LB*) group="L3CACHE" ;;
      *MR*) group="MEMREAD" ;;
      *MW*) group="MEMWRITE" ;;
      *)    echo "Error: group not defined yet"; exit 1 ;;
    esac
    part1="likwid-perfctr -C $CV -g $group -m"
    ;;
  lwp)
    part1="likwid-pin -c $CV -m"
    ;;
esac

case $mod in
  lwb)
    part2="likwid-bench"
    ;;
esac

W=$(echo $ker | cut -d '+' -f 1 | sed 's/^0*//')
case $ker in
  *pd000) kernel="peakflops" ;;
  *pds00) kernel="peakflops_sse" ;;
  *pda00) kernel="peakflops_avx" ;;
  *pdaf0) kernel="peakflops_avx_fma" ;;
  *pda50) kernel="peakflops_avx512" ;;
  *pda5f) kernel="peakflops_avx512_fma" ;;
  *ps000) kernel="peakflops_sp" ;;
  *pss00) kernel="peakflops_sp_sse" ;;
  *psa00) kernel="peakflops_sp_avx" ;;
  *psaf0) kernel="peakflops_sp_avx_fma" ;;
  *psa50) kernel="peakflops_sp_avx512" ;;
  *psa5f) kernel="peakflops_sp_avx512_fma" ;;

  *sdma00) kernel="stream_mem_avx" ;;
  *sdma50) kernel="stream_mem_avx512" ;;

  *ld00) kernel="load" ;;
  *lda0) kernel="load_avx" ;;
  *lda5) kernel="load_avx512" ;;
  *ldm0) kernel="load_mem" ;;
  *lds0) kernel="load_sse" ;;

  *)    echo "Error: ker not defined yet"; exit 1 ;;
esac

part3="-t $kernel"
case $kernel in
  peak*)
    PW=$(( $W * $run_threads ))KB
    #part4="-W N:$PW:$run_threads -i 1000" 
    part4="-W N:$PW:$run_threads" 
    ;;
  stream*) 
    SW=$(( $W * $run_threads ))MB
    #part4="-W N:$SW:$run_threads -i 50" 
    part4="-W N:$SW:$run_threads"
    ;;
  load*)
    LW=$(( $W * $run_threads ))KB
    #part4="-W S0:$LW:$run_threads -i 50000"
    part4="-W S0:$LW:$run_threads"
    ;;
  *)       
    echo "Error: kernel not defined yet"; exit 1 
    ;;
esac

te=$(date +%s)
tb=$((te-ts))

exec="$part0 $part1 $part2 $part3 $part4"

## Run
ts=$(date +%s)
prof_output="${expid}_${work}"
if [[ $machine == "cosma8" ]]; then
  set +xuve
  source $HOME/intel/oneapi/setvars.sh
  module load linaro/forge/23.1.0
  set -xuve
else
  echo "Error: $machine not defined yet"; exit 1
fi
if [[ $run_procs == "seq" ]]; then
  case $testcase in
    def*)
      $exec
      ;;
    iac*) # advisor: Error: [Instrumentation Engine]: /tmp_proj/pin_jenkins/workspace/pypl-pin-nightly/GitPin/Source/pin/elfio/elf_parser.cpp: ProcessSectionHeaders: 827: strange section type for .annobin.notes
      date
      advisor --collect=survey                     $exec
      date
      advisor --collect=tripcounts --flop --stacks $exec
      date
      advisor -collect=map --enable-cache-simulation $exec
      date
      ;;
    *)
      echo "Error: $testcase not defined yet"; exit 1
      ;;
  esac
else
  case $testcase in
    def)
      mpirun -n $run_procs $exec
      ;;
    *)
      echo "Error: $testcase not defined yet"; exit 1      
      ;;
  esac
fi

te=$(date +%s)
tr=$((te-ts))

