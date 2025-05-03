#!/bin/bash

# This script attaches to the iOS simulator with ID 325985CC-C12D-4BF9-BC82-59B7AB1ACB66,
# captures the Flutter logs, and saves them to offline_restart.log while also displaying them in the terminal
# The log will will be saved to the current directory.
stdbuf -oL flutter logs -d 325985CC-C12D-4BF9-BC82-59B7AB1ACB66 | tee offline_restart.log