#!/bin/bash
EXECUTABLE="lua participant.lua"
IP="127.0.0.1"
PORT=53709
HEADCOUNT=$1
STAMP=$(date '+%H:%M:%S')
LOG_DIR="log/$STAMP"

mkdir -p "$LOG_DIR"

# start master
$EXECUTABLE "$HEADCOUNT" > "$LOG_DIR/master.log" 2>&1 & MASTER_PID=$!
echo "Master process started (PID=$MASTER_PID), logs in $LOG_DIR/master.log"

# start slaves
for i in $(seq 2 $HEADCOUNT); do
  $EXECUTABLE > "$LOG_DIR/participant_$i.log" 2>&1 &
  echo "Started participant $i, logs in $LOG_DIR/participant_$i.log"
done

# wait for master
wait $MASTER_PID
echo "Master process (PID=$MASTER_PID) has completed."

echo "Waiting for all background processes to finish..."
wait
echo "All participant processes have completed."

# check against master
function compare ()
{
  master=$(tail -1 "$LOG_DIR/master.log" | grep -Eo '[0-9]+.[0-9]?$')
  line=$(tail -1 "$1" | grep -Eo '[0-9]+.[0-9]?$')
  if [[ $master != $line ]]
  then
    echo "SMPC failed: mismatching values" && exit 1
  fi
}

# check
for participant in $LOG_DIR/*.log; do
  compare $participant
done

echo "SMPC was a success!"
exit 0
