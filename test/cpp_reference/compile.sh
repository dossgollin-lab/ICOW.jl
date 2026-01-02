#!/bin/bash
# Compile debugged C++ reference code for ICOW

echo "Compiling debugged ICOW C++ reference code..."

# Create outputs directory if it doesn't exist
mkdir -p outputs

# Compile with Homebrew g++-15
# -std=c++11: Use C++11 standard
# -O2: Optimization level 2
# -o icow_test: Output executable name
/opt/homebrew/bin/g++-15 -o icow_test icow_debugged.cpp -std=c++11 -O2

if [ $? -eq 0 ]; then
    echo "✓ Compilation successful!"
    echo "Run with: ./icow_test"
else
    echo "✗ Compilation failed!"
    exit 1
fi
