#!/bin/bash

# Utility script that allows to track changes in system settings

echo "Dumping 'before' settings..."
defaults read > before

echo "Perform manually required settings and press Enter..."
read -r

echo "Dumping 'after' settings..."
defaults read > after
