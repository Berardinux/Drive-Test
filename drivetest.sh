#!/bin/bash

# Define the list of drives to test
drives=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")

# Log all output to /var/log/drivetest.log
exec &> tee -a /var/log/drivetest.log

# Loop through the drives and start the long test in parallel
echo "Starting long tests for all drives..."
parallel --bar smartctl -t long ::: "${drives[@]}"
echo "Long tests started for all drives."

# Wait for the tests to complete
echo "Waiting for tests to complete..."
parallel --bar 'while smartctl -a {} | grep -q "Self-test execution status: .*in progress"; do sleep 10; done' ::: "${drives[@]}"
echo "All tests completed."

# Check for failed drives and log the result
failed=false
for drive in "${drives[@]}"; do
  if smartctl -a "$drive" | grep -q "Self-test execution status: .*completed"; then
    if smartctl -a "$drive" | grep -q "Overall SMART status:.*FAILED!"; then
      failed=true
      echo "Test for $drive failed!" | tee -a /var/log/drivetest.log
      echo "Test for $drive failed!" > /home/berardinux/failed_drive.txt
    fi
  else
    echo "Test for $drive did not complete!" | tee -a /var/log/drivetest.log
  fi
done

# Display the results
echo "Results:"
for drive in "${drives[@]}"; do
  echo "Results for $drive:"
  smartctl -a "$drive" | grep -E "SMART overall-health|Self-test execution status|SMART Error Log" | sed 's/^/\t/'
done

if [ "$failed" = true ]; then
  echo "One or more drives failed the test!" | tee -a /var/log/drivetest.log
else
  echo "All drives passed the test." | tee -a /var/log/drivetest.log
fi
