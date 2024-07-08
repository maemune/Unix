#!/bin/bash

file_name=$(hostname)
echo "y" | ssh-keygen -t ed25519 -f ~/.ssh/$file_name -N "" -C "" -q
