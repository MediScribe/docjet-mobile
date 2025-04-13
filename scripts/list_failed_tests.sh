#!/bin/sh

flutter test | grep "To run this test again: " | awk '{filePath = $8; testName = ""; for (i=12; i<=NF; i++) { testName = testName $i " " }; print "Failed: " filePath " : " testName}'
