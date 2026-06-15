#!/bin/sh
CHIP=${1:-gpiochip0}
PIN=${2:-1}
TOTAL=${3:-45}
INTERVAL=${4:-5}
echo GPIO DMM TOGGLE $CHIP line $PIN
echo ${INTERVAL}s HIGH then ${INTERVAL}s LOW for ${TOTAL}s total
gpioset $CHIP $PIN=0 2>/dev/null
elapsed=0
cycle=0
while [ $elapsed -lt $TOTAL ]; do
  cycle=$((cycle+1))
  echo HIGH cycle $cycle
  gpioset --mode=time --sec=$INTERVAL $CHIP $PIN=1
  elapsed=$((elapsed+INTERVAL))
  if [ $elapsed -ge $TOTAL ]; then break; fi
  echo LOW cycle $cycle
  gpioset --mode=time --sec=$INTERVAL $CHIP $PIN=0
  elapsed=$((elapsed+INTERVAL))
done
gpioset $CHIP $PIN=0
echo DMM TOGGLE DONE $CHIP line $PIN held LOW
