#!/bin/bash

# --- Configuration ---
SERVER_PORT=8080
MAX_STARTUP_WAIT=5  # Maximum seconds to wait for server startup
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
MOCK_SERVER_DIR="$SCRIPT_DIR/../mock_api_server"
SERVER_START_CMD="dart bin/server.dart --port $SERVER_PORT"
MOCK_SERVER_FINGERPRINT="dart bin/server.dart"  # Used to identify our process vs others
# --- End Configuration ---

# --- Check for dependencies ---
check_dependencies() {
    local missing_deps=()
    
    # Check for lsof (used to find processes by port)
    if ! command -v lsof &> /dev/null; then
        missing_deps+=("lsof")
    fi
    
    # Check for dart (needed to run the server)
    if ! command -v dart &> /dev/null; then
        missing_deps+=("dart")
    fi
    
    # If any dependencies are missing, print error and exit
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install these tools before running this script."
        exit 1
    fi
}

# Call the dependency check
check_dependencies

# Function to check if server is running on our port
is_server_running() {
    lsof -t -i:$SERVER_PORT > /dev/null 2>&1
    return $? # 0 if running, non-zero otherwise
}

# Function to find the server PID
get_server_pid() {
    lsof -t -i:$SERVER_PORT 2>/dev/null
}

# Function to check if a PID belongs to our mock server
is_our_mock_server() {
    local pid=$1
    ps -p "$pid" -o command= 2>/dev/null | grep -q "$MOCK_SERVER_FINGERPRINT"
    return $?  # 0 if it matches, non-zero otherwise
}

# Function to stop the server
stop_server() {
    local pid
    pid=$(get_server_pid)
    
    if [ -n "$pid" ]; then
        # Safety check - only kill our mock server, not any random process on this port
        if is_our_mock_server "$pid"; then
            echo "--> Stopping Mock Server (PID: $pid)..."
            kill "$pid" > /dev/null 2>&1
            sleep 0.5
            
            if kill -0 "$pid" 2>/dev/null; then
                echo "    Graceful stop failed. Forcing kill (SIGKILL)..."
                kill -9 "$pid" > /dev/null 2>&1
                sleep 0.5
            fi
            
            if kill -0 "$pid" 2>/dev/null; then
                echo "    Error: Failed to stop process $pid."
                return 1
            fi
            
            echo "    Server stopped."
            return 0
        else
            echo "    WARNING: Process on port $SERVER_PORT (PID: $pid) is NOT our mock server!"
            echo "    Command: $(ps -p "$pid" -o command=)"
            echo -n "    Do you want to kill it anyway? (y/N) "
            read -r confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                echo "    Stopping non-mock process (PID: $pid)..."
                kill "$pid" > /dev/null 2>&1
                sleep 0.5
                if kill -0 "$pid" 2>/dev/null; then
                    kill -9 "$pid" > /dev/null 2>&1
                    sleep 0.5
                fi
                echo "    Process stopped."
                return 0
            else
                echo "    Aborted. Port $SERVER_PORT is still in use by another process."
                return 1
            fi
        fi
    else
        echo "--> Server not running. Nothing to stop."
        return 0
    fi
}

# Function to start the server
start_server() {
    echo "--> Starting Mock Server..."
    if [ ! -d "$MOCK_SERVER_DIR" ]; then
        echo "    Error: Mock server directory not found at $MOCK_SERVER_DIR"
        return 1
    fi

    # Ensure port is free first
    if is_server_running; then
        local pid
        pid=$(get_server_pid)
        if is_our_mock_server "$pid"; then
            echo "    Mock server is already running (PID: $pid)."
            return 0
        else
            echo "    Error: Port $SERVER_PORT is in use by another application (PID: $pid)."
            echo "    Command: $(ps -p "$pid" -o command=)"
            echo "    Use option 2 to stop it first (with caution)."
            return 1
        fi
    fi

    # Navigate, start, and go back
    original_dir=$(pwd)
    cd "$MOCK_SERVER_DIR" || { echo "Failed to change directory to $MOCK_SERVER_DIR"; return 1; }
    echo "    Executing: $SERVER_START_CMD &"
    $SERVER_START_CMD &
    cd "$original_dir" || { echo "Failed to return to original directory"; return 1; }

    # Wait for server to start
    echo -n "    Waiting for server to start"
    for _ in $(seq 1 $MAX_STARTUP_WAIT); do
        if is_server_running; then
            echo # Newline after dots
            pid=$(get_server_pid)
            echo "    Server started successfully (PID: $pid)."
            return 0
        fi
        echo -n "."
        sleep 1
    done
    
    echo # Newline after dots
    echo "    Error: Server failed to start within $MAX_STARTUP_WAIT seconds."
    return 1
}

# --- Main Menu Function ---
show_menu() {
    clear
    echo "=========================="
    echo "  Mock Server Controller"
    echo "  Port: $SERVER_PORT"
    echo "=========================="
    
    # Get current status
    if is_server_running; then
        local pid
        pid=$(get_server_pid)
        if is_our_mock_server "$pid"; then
            echo "STATUS: RUNNING MOCK SERVER (PID: $pid)"
        else
            echo "STATUS: PORT IN USE BY OTHER PROCESS (PID: $pid)"
            echo "        Command: $(ps -p "$pid" -o command= | head -c 50)..."
        fi
    else
        echo "STATUS: STOPPED"
    fi
    
    echo ""
    echo "1) Start Server"
    echo "2) Stop Server"
    echo "3) Toggle Server"
    echo "4) Check Status"
    echo "5) Start ALL Progressions"
    echo "6) Stop ALL Progressions"
    echo "7) Reset ALL Progressions"
    echo "8) Exit"
    echo ""
    echo -n "Enter option [1-8]: "
}

# --- Main Loop ---
while true; do
    show_menu
    read -r option
    
    case $option in
        1)  
            if is_server_running; then
                pid=$(get_server_pid)
                if is_our_mock_server "$pid"; then
                    echo "Mock server is already running (PID: $pid)."
                else
                    echo "Port $SERVER_PORT is in use by another process (PID: $pid)."
                    echo "Command: $(ps -p "$pid" -o command=)"
                    echo "Use option 2 to stop it first (with caution)."
                fi
            else
                start_server
            fi
            echo "Press Enter to continue..."
            read -r
            ;;
        2)  
            if is_server_running; then
                stop_server
            else
                echo "No process is running on port $SERVER_PORT."
            fi
            echo "Press Enter to continue..."
            read -r
            ;;
        3)  
            if is_server_running; then
                # TRUE TOGGLE: Just stop if running, don't automatically start
                echo "Toggle: Server is running, stopping it..."
                stop_server
            else
                # TRUE TOGGLE: Just start if stopped
                echo "Toggle: Server is stopped, starting it..."
                start_server
            fi
            echo "Press Enter to continue..."
            read -r
            ;;
        4)  
            if is_server_running; then
                pid=$(get_server_pid)
                if is_our_mock_server "$pid"; then
                    echo "Port $SERVER_PORT is being used by our mock server (PID: $pid)"
                    echo "Command: $(ps -p "$pid" -o command=)"
                else
                    echo "WARNING: Port $SERVER_PORT is being used by another process (PID: $pid)"
                    echo "Command: $(ps -p "$pid" -o command=)"
                fi
            else
                echo "Port $SERVER_PORT is not in use by any process."
            fi
            echo "Press Enter to continue..."
            read -r
            ;;
        5)  
            if is_server_running; then
                echo "--> Triggering Start Progression for ALL jobs..."
                response=$(curl -s -X POST "http://localhost:$SERVER_PORT/api/v1/debug/jobs/start")
                echo "$response"
                echo "Trigger command sent. Check server logs for details."
            else
                echo "Error: Mock server is not running. Start it first (option 1)."
            fi
            echo "Press Enter to continue..."
            read -r
            ;;
        6)  
            if is_server_running; then
                echo "--> Triggering Stop Progression for ALL jobs..."
                response=$(curl -s -X POST "http://localhost:$SERVER_PORT/api/v1/debug/jobs/stop")
                echo "$response"
                echo "Trigger command sent. Check server logs for details."
            else
                echo "Error: Mock server is not running. Start it first (option 1)."
            fi
            echo "Press Enter to continue..."
            read -r
            ;;
        7)  
            if is_server_running; then
                echo "--> Triggering Reset Progression for ALL jobs..."
                response=$(curl -s -X POST "http://localhost:$SERVER_PORT/api/v1/debug/jobs/reset")
                echo "$response"
                echo "Trigger command sent. Check server logs for details."
            else
                echo "Error: Mock server is not running. Start it first (option 1)."
            fi
            echo "Press Enter to continue..."
            read -r
            ;;
        8)  
            echo "Exiting..."
            # Optionally stop server on exit
            if is_server_running; then
                pid=$(get_server_pid)
                if is_our_mock_server "$pid"; then
                    echo -n "Stop mock server before exiting? (Y/n) "
                    read -r confirm
                    if [[ ! $confirm =~ ^[Nn]$ ]]; then
                        stop_server
                    fi
                else
                    echo "Note: Port $SERVER_PORT is in use by a non-mock process (PID: $pid)."
                    echo "This process will continue running after exit."
                fi
            fi
            exit 0
            ;;
        *)  
            echo "Invalid option. Press Enter to continue..."
            read -r
            ;;
    esac
done 