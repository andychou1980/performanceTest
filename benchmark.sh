#!/bin/bash

# Set the count variable
COUNT=10000

# Initialize the CSV file
csv_file="benchmark_results_$(date +'%Y%m%d_%H%M%S').csv"
echo "Operation,Block Size,Streams,Time Taken (s),Speed (MB/s)" > $csv_file

# Function to parse time taken in seconds
parse_time() {
    local time_str=$1
    local minutes=$(echo $time_str | cut -d'm' -f1)
    local seconds=$(echo $time_str | cut -d'm' -f2 | sed 's/s//')
    local total_seconds=$(echo "$minutes * 60 + $seconds" | bc -l)
    echo $total_seconds
}

# Function to perform the test
perform_test() {
    local block_size=$1
    local operation=$2
    local streams=$3
    local file="testfile"
    local log_file="${streams}_streams_${operation}_${block_size}.log"

    if [[ "$operation" == "write" ]]; then
        for ((i=1; i<=streams; i++)); do
            command="dd if=/dev/zero of=${file}_$i bs=$block_size count=$COUNT oflag=direct"
            echo "Running: $command"
            echo "Command: $command" >> $log_file
            (time $command) &>> $log_file &
        done
    elif [[ "$operation" == "read" ]]; then
        for ((i=1; i<=streams; i++)); do
            command="dd if=${file}_$i of=/dev/null bs=$block_size iflag=direct"
            echo "Running: $command"
            echo "Command: $command" >> $log_file
            (time $command) &>> $log_file &
        done
    elif [[ "$operation" == "write+read" ]]; then
        for ((i=1; i<=streams; i++)); do
            command="time (dd if=/dev/zero of=${file}_$i bs=$block_size count=$((COUNT/2)) oflag=direct && dd if=${file}_$i of=/dev/null bs=$block_size iflag=direct)"
            echo "Running: $command"
            echo "Command: $command" >> $log_file
            eval $command &>> $log_file &
        done
    elif [[ "$operation" == "random_write" ]]; then
        for ((i=1; i<=streams; i++)); do
            command="dd if=/dev/urandom of=${file}_$i bs=$block_size count=$COUNT oflag=direct"
            echo "Running: $command"
            echo "Command: $command" >> $log_file
            (time $command) &>> $log_file &
        done
    elif [[ "$operation" == "random_read" ]]; then
        for ((i=1; i<=streams; i++)); do
            command="dd if=${file}_$i of=/dev/null bs=$block_size iflag=direct"
            echo "Running: $command"
            echo "Command: $command" >> $log_file
            (time $command) &>> $log_file &
        done
    elif [[ "$operation" == "random_write+read" ]]; then
        for ((i=1; i<=streams; i++)); do
            command="time (dd if=/dev/urandom of=${file}_$i bs=$block_size count=$((COUNT/2)) oflag=direct && dd if=${file}_$i of=/dev/null bs=$block_size iflag=direct)"
            echo "Running: $command"
            echo "Command: $command" >> $log_file
            eval $command &>> $log_file &
        done
    fi

    wait

    # Extract time taken and calculate speed
    raw_time=$(grep real $log_file | awk '{print $2}')
    time_taken=$(parse_time $raw_time)
    total_data_mb=$(echo "$streams * $COUNT * ${block_size%K} / 1024" | bc -l)
    speed=$(echo "$total_data_mb / $time_taken" | bc -l)
    speed=$(printf "%.2f" $speed)

    # Record time taken and speed into CSV
    echo "$operation,$block_size,$streams,$time_taken,$speed" >> $csv_file

    # Delete temporary files
    for ((i=1; i<=streams; i++)); do
        rm -f ${file}_$i
    done
}

# Function to consolidate logs into a report
consolidate_logs() {
    local report_file="benchmark_report_$(date +'%Y%m%d_%H%M%S').txt"
    echo "Benchmark Report - $(date)" > $report_file
    echo "============================" >> $report_file
    echo "Current Directory: $(pwd)" >> $report_file
    echo "Test Start Time: $start_time" >> $report_file
    echo "Test End Time: $(date)" >> $report_file
    echo "============================" >> $report_file

    for log in *.log; do
        echo "Results for $log" >> $report_file
        echo "----------------------------" >> $report_file
        cat $log >> $report_file
        echo "----------------------------" >> $report_file
        echo "" >> $report_file
        rm $log
    done

    cat $report_file
}

# Array of block sizes
block_sizes=("4K" "1024K")

# Array of operations
operations=("write" "read" "write+read" "random_write" "random_read" "random_write+read")

# Array of streams
streams=(1 2 4)

# Show current directory
echo "Current Directory: $(pwd)"

# Record start time
start_time=$(date)
echo "Test Start Time: $start_time"

# Perform the tests
for stream in "${streams[@]}"; do
    for block_size in "${block_sizes[@]}"; do
        for operation in "${operations[@]}"; do
            echo "Performing $operation with block size $block_size using $stream streams"
            perform_test $block_size $operation $stream
        done
    done
done

# Consolidate logs into a report
consolidate_logs

echo "All tests completed. Report saved and displayed above."
