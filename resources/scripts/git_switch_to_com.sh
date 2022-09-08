#!/bin/bash

# Set local git committer for company profile

fileWithEmail="$HOME/.config/company_email.txt"

if [ ! -f "$fileWithEmail" ]
  then
    echo "Your company email hasn't been set yet. Provide it below:"
    read companyEmail
    echo "$companyEmail" > "$fileWithEmail"
fi

if [ -f "$fileWithEmail" ]
  then
    name="Herman Ciechanowiec"
    companyEmail=$(head -n 1 "$fileWithEmail")
    git config user.name "$name"
    git config user.email "$companyEmail"
    echo "The following local git committer has been set:"
    echo "$name"
    echo "$companyEmail"
  else
    echo "Error occurred. Aborting..."
fi
