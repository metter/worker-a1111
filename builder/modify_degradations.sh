#!/bin/bash

# File path
FILE_PATH="/usr/local/lib/python3.10/site-packages/basicsr/data/degradations.py"

# Display the relevant line(s) before modification
echo "Before modification:"
grep "rgb_to_grayscale" $FILE_PATH

# Perform the modification
sed -i 's/from torchvision.transforms.functional_tensor import rgb_to_grayscale/from torchvision.transforms.functional import rgb_to_grayscale/' $FILE_PATH

# Display the relevant line(s) after modification
echo "After modification:"
grep "rgb_to_grayscale" $FILE_PATH
