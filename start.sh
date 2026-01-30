#!/bin/bash
# Start Kestra and dependencies
# Run this before starting Claude Code to ensure MCP server can connect

set -e

echo "Starting Kestra workflow environment..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "Please edit .env with your actual credentials"
fi

# Start containers
docker-compose up -d

# Wait for Kestra to be ready
echo "Waiting for Kestra to start..."
until curl -s -u "admin@kestra.io:Kestra2024" http://localhost:8080/api/v1/flows > /dev/null 2>&1; do
    sleep 2
    echo -n "."
done

echo ""
echo "Kestra is running at http://localhost:8080"
echo "Username: admin@kestra.io"
echo "Password: Kestra2024"
echo ""
echo "You can now start Claude Code in this directory."
