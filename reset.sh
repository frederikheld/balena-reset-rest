#!/bin/bash


## -- config

if [ -z "${DEBUG_OUT}" ]
then
    DEBUG_OUT="/dev/null" # route output to /dev/null if no serial or file path is configured
fi
ENDPOINTS_FILE="endpoints.txt"

#echo "DEBUG_OUT=${DEBUG_OUT}" | tee "/dev/ttyS0"

# -- setup

# TODO: this approach uses the outdated `sysfs` interface for GPIO.
# Since Linux Kernel 4.8 (2018) this is deprecated an replaced by the
# new `chardev` interface. `sysfs` will still be around for a while and
# there are not many ressources for `chardev` yet, so it is not urgent
# to switch yet, but we should be aware that it will be neccessary some
# time in te future.
# See: https://embeddedbits.org/new-linux-kernel-gpio-user-space-interface/

# NOTE: echo to /sys/class/gpio/exports throws an "I/O error" if the pin
# was exported before. It will work anyway!

echo "${GPIO_RESET_IN}" > /sys/class/gpio/export
echo "in" > /sys/class/gpio/gpio${GPIO_RESET_IN}/direction

echo "${GPIO_ACK_OUT}" > /sys/class/gpio/export
echo "out" > /sys/class/gpio/gpio${GPIO_ACK_OUT}/direction
echo "0" > /sys/class/gpio/gpio${GPIO_ACK_OUT}/value


# -- functions

# Blinks the LED on the given pin
#
# $ blink_led pin count pause
#
# pin: pin
# count: number of blinks
# pause: time between blinks
blink_led() {
    PIN=$1
    COUNT=$2
    PAUSE=$3

    counter=0
    while [ $counter -lt $COUNT ]
    do
        counter=$((counter+1))
        echo "1" > /sys/class/gpio/gpio${PIN}/value
        sleep $PAUSE
        echo "0" > /sys/class/gpio/gpio${PIN}/value
        sleep $PAUSE
    done
}


# -- main

# exit if button is not pressed:
button_in_value=$(cat /sys/class/gpio/gpio${GPIO_RESET_IN}/value)
if [ $button_in_value -eq 0 ]
then
    echo "Reset button not pressed. No reset will be conducted." | tee $DEBUG_OUT
    exit 0
fi

# call all configured reset endpoints:
success=1
while read http_method expected_status endpoint || [ -n "$endpoint" ]
do
    if [[ $endpoint =~ [^[:space:]] ]]
    then

        # # DEBUG
        echo "Attempting to reset \"${http_method} ${endpoint}\". Expecting response status code \"${expected_status}\"" | tee $DEBUG_OUT
        # curl -X ${http_method} ${endpoint} | tee $DEBUG_OUT

        response=$(curl -s -o /dev/null -w "%{http_code}" -X ${http_method} ${endpoint}) # TODO: Replace with docker-internal hostname (this seems to be a bit tricky with balenaOS)
        echo "Response code: ${response}"
        if [[ $response -eq $expected_status ]]
        then
            # Confirm deletion to user:
            echo "> Response was \"${response}\" --> Success" | tee $DEBUG_OUT
        else
            # Warn user about failure:
            echo "> Response was \"${response}\" --> Failed" | tee $DEBUG_OUT
            success=1
        fi

    fi
done < "${ENDPOINTS_FILE}"

# Give visual feedback:
if [ $success -eq 1 ]
then
    echo "Reset successful." | tee $DEBUG_OUT
    blink_led ${GPIO_ACK_OUT} 3 0.2
else
    echo "Reset failed for at least one operation (see output above)." | tee $DEBUG_OUT
    blink_led ${GPIO_ACK_OUT} 10 0.1
fi

exit 0
