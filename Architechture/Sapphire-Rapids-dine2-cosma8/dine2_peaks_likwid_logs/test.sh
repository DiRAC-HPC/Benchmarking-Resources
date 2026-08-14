#!/bin/bash

set -xuve

f="lkd"

p="cosma8-dine2-intel"

prs="seq"

#ts="1 32 64"
#ts="1 2 4 8 16 18 32"
ts="1 2 3 4 8 12 16 20 24 28 32 64"
#ts="1 8 16 32 64"

##t44
#cs="
#n1-lwpcFA-lwb-0001+pda5f
#n1-lwpcFA-lwb-0002+pda5f
#n1-lwpcFA-lwb-0004+pda5f
#n1-lwpcFA-lwb-0008+pda5f
#n1-lwpcFA-lwb-0016+pda5f
#n1-lwpcFA-lwb-0024+pda5f
#n1-lwpcFA-lwb-0032+pda5f
#n1-lwpcFA-lwb-0040+pda5f
#n1-lwpcFA-lwb-0048+pda5f
#n1-lwpcFA-lwb-0056+pda5f
#n1-lwpcFA-lwb-0064+pda5f
#n1-lwpcFA-lwb-0128+pda5f
#n1-lwpcFA-lwb-0256+pda5f
#n1-lwpcFA-lwb-0512+pda5f
#n1-lwpcFA-lwb-1024+pda5f
#n1-lwpcFA-lwb-2048+pda5f
#n1-lwpcFA-lwb-4096+pda5f
#n1-lwpcFA-lwb-8192+pda5f
#"

##t45, t59
#cs="
#n1-lwpcFA-lwb-0032+pda5f
#n1-lwpcFA-lwb-0032+psa5f
#"

##t46, t60
#cs="
#n1-lwpcMM-lwb-2048+sdma50
#"

#t47, t61
cs="
n1-lwpcL2-lwb-2048+lda5
n1-lwpcL3-lwb-61440+lda5
"

##t48
#cs="
#n1-lwpcL3-lwb-0001+lda5
#n1-lwpcL3-lwb-0002+lda5
#n1-lwpcL3-lwb-0004+lda5
#n1-lwpcL3-lwb-0008+lda5
#n1-lwpcL3-lwb-0016+lda5
#n1-lwpcL3-lwb-0032+lda5
#n1-lwpcL3-lwb-0064+lda5
#n1-lwpcL3-lwb-0128+lda5
#n1-lwpcL3-lwb-0256+lda5
#n1-lwpcL3-lwb-0512+lda5
#n1-lwpcL3-lwb-1024+lda5
#n1-lwpcL3-lwb-2048+lda5
#n1-lwpcL3-lwb-4096+lda5
#n1-lwpcL3-lwb-8192+lda5
#"

#cs="
#n1-lwpcFA-lwb-2048+lda5
#n1-lwpcMM-lwb-2048+lda5
#n1-lwpcL2-lwb-2048+lda5
#n1-lwpcL3-lwb-2048+lda5
#n1-lwpcLA-lwb-2048+lda5
#n1-lwpcLB-lwb-2048+lda5
#"

#cs="n1-lwpcFD-lwb-0024+pda5f"

tcs="deft61"
#tcs="iact52"

cpn="64"

## li: login or db: debug  or qs: queue system
launch="li"
#launch="db"
#launch="qs"
# in case of "qs" additional stuff
#sbatch_common="--time=01:00:00 -p cosma8-milan -A dr004" # Milan 16:3h, 32:2h, 64:1.5h, 128:1h
#sbatch_common="--time=00:10:00 -p cosma8-shm3 -A dr004 --exclusive" # Genoa
sbatch_common="--time=00:30:00 -p dine2 -A do015 --exclusive" # Sapphire Rapids
#sbatch_common="--time=02:00:00 -p dine2 -A do015 --exclusive --cpu-freq=3400000" # Sapphire Rapids
#sbatch_common="--time=01:00:00 -p dine2 -A durham --exclusive" # Sapphire Rapids
## most of the time no need to go beyond this line:
for tc in $tcs; do
  for c in $cs; do
    for pr in $prs; do
      for t in $ts; do
        ntpn=$(($cpn/$t))
        cpt="--cpus-per-task=$t"
        tpc=""
        #tpc="--threads-per-core=1"
        if [[ $pr == "seq" ]]; then
          pr1=seq-$(printf "%03d" $t)
          sbatch_options="--nodes=1 --ntasks-per-node=1 $cpt $tpc"
        else
          nt="--ntasks=$pr"
          pr1=$(printf "%03d" $pr)-$(printf "%03d" $t)
          if [[ $pr -lt $ntpn  ]]; then
            sbatch_options="$nt --nodes=1 --ntasks-per-node=$ntpn $cpt $tpc"
          else
            if [[ $(($pr%$ntpn)) == 0 ]]; then
              nodes=$(($pr/$ntpn))
            else
              nodes=$(($(($pr/$ntpn))+1))
            fi
            sbatch_options="$nt --nodes=$nodes --ntasks-per-node=$ntpn $cpt $tpc"
          fi
        fi
        job=${f}_${p}_${pr1}_${c}_${tc}
    
        cmd="./deploy.sh $f $p ${pr}-${t} $c $tc"
        
        case $launch in
          li)
            set +xuve
            #$cmd >& ${job}_$(date +%Y%m%d%H%M%S).log &
            $cmd >& ${job}_$(date +%Y%m%d%H%M%S).log
            set -xuve
            ;;
          db)
            $cmd
            ;;
          qs)
            while true; do
              set +xuve
                           sbatch -J ${job} -o ${job}_%J.log -e ${job}_%J.log $sbatch_options $sbatch_common $cmd; check=$?
              echo $check: sbatch -J ${job} -o ${job}_%J.log -e ${job}_%J.log $sbatch_options $sbatch_common $cmd
              set -xuve
              if [[ $check -eq 0 ]]; then
                break
              else
                sleep 60
              fi
            done
            sleep 1
            ;;
        esac
      done
    done
  done
done

sleep 2
ls -lrth
squeue -u $USER

