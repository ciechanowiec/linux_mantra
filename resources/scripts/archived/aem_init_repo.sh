#!/bin/bash

touch .repo

cat > .repo << EOF
server=http://localhost:4502
credentials=admin:admin
EOF
