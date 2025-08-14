#!/bin/bash

# Force Python to use 1 core per subprocess
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

rep=50
ml=BART_MI
for n in 500 1000 1500 2000; do
    for snr in 0 20 15 10 5 2 1 0.5 0.25; do
        echo "Running Feynman datasets with n = ${n}, SNR = ${snr}..."
        # Run the command with nohup and wait for it to finish
        nohup python analyze.py ../feynman_dataset/ \
            -results ../results/${ml}/n_${n}/ \
            -script BART_selection \
            -signal_to_noise $snr \
            -n $n \
            -sym_data \
            -n_trials 10 \
            -n_jobs 20 \
            -rep $rep \
            -time_limit 24:00 \
            -job_limit 1000 \
            -ml $ml \
            --local \
            >"logs/$ml/n_${n}/feynman_${ml}_n${n}_snr${snr}.out" \
            2>"logs/$ml/n_${n}/feynman_${ml}_n${n}_snr${snr}.err" &

        python_pid=$!
        echo "Started process with PID: $python_pid"

        # Wait for the background job to finish
        wait $python_pid

        # Check the exit status of the nohup command
        if [ $? -gt 0 ]; then
            echo "Job with n = ${n}, SNR = ${snr} failed, exiting loop."
            break
        fi
    done
done