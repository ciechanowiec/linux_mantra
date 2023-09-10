#!/bin/bash

# Utility script that allows to track changes in system settings

echo "Removing old files..."
sudo rm -rf UserBefore
sudo rm -rf UserAfter

sudo rm -rf SystemBefore
sudo rm -rf SystemAfter

echo "Dumping user-wide 'before' settings..."
cp -r ~/Library/Preferences UserBefore
echo "Dumping system-wide 'before' settings..."
sudo cp -r /Library/Preferences SystemBefore

echo "Perform manually required settings and press Enter..."
read void

echo "Dumping user-wide 'after' settings..."
cp -r ~/Library/Preferences UserAfter
echo "Dumping system-wide 'after' settings..."
sudo cp -r /Library/Preferences SystemAfter

echo ""
echo "USER-WIDE SETTINGS COMPARISON:"
sudo diff -ur UserBefore UserAfter

echo ""
echo "SYSTEM-WIDE SETTINGS COMPARISON:"
sudo diff -ur SystemBefore SystemAfter
