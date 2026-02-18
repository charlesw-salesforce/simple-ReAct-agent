#!/bin/bash

# Deploy Simple ReAct Agent Demo
# Usage: ./bin/deploy.sh [target-org]

set -e

TARGET_ORG="${1:-}"

echo "🚀 Deploying Simple ReAct Agent..."
echo ""

# Deploy project
if [ -n "$TARGET_ORG" ]; then
  echo "📦 Deploying to org: $TARGET_ORG"
  sf project deploy start --target-org "$TARGET_ORG"
else
  echo "📦 Deploying to default org"
  sf project deploy start
fi

echo ""
echo "✅ Deployment complete!"
echo ""

# Assign permission set
echo "🔐 Assigning Agent_Chat_User permission set..."
if [ -n "$TARGET_ORG" ]; then
  sf org assign permset --name Agent_Chat_User --target-org "$TARGET_ORG"
else
  sf org assign permset --name Agent_Chat_User
fi

echo ""
echo "✅ Permission set assigned!"
echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Open Prompt Builder in Setup"
echo "2. Create a Lightning Type matching AgentOutput fields"
echo "3. Create a prompt template (name it 'Agentic_Template')"
echo "4. Open the Agent Chat app from the App Launcher"
echo ""
echo "For detailed setup instructions, see README.md"
