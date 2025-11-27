#!/bin/bash

# ------- Color Definitions ------- #
CLR_GRN='\033[38;2;58;204;140m'
CLR_RED='\033[0;31m'
CLR_RST='\033[0m'

# --- Execution ---
echo "--- Running Norminette Check ---"
# Pass all arguments ($@) directly to the norminette command
/usr/bin/env norminette "$@"

# ------- Check Exit Code ------- #
EXIT_CODE=$?

# ------- Print Result (Colored) ------- #
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "\n${CLR_GRN}============================"
    echo -e "========= NORM OK! ========="
    echo -e "============================${CLR_RST}"
else
	echo -e "\n${CLR_RED}==============================="
    echo -e "====== NORM ERRORS FOUND ======"
	echo -e "===============================${CLR_RST}"
fi