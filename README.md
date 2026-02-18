# Simple ReAct Agent

A simple ReAct agent implementation in pure Apex and Prompt Builder to demonstrate how agentic patterns work.

## ⚠️ Important Disclaimer

**This is for learning purposes only. Do not use in production.**

For real-world agent applications on Salesforce, use **[Agentforce](https://www.salesforce.com/agentforce/)**.

Agentforce provides:
- Production-ready reliability and error handling
- Proper state management and conversation history
- Built-in governance and safety features
- Monitoring and observability
- Enterprise security and compliance
- Optimized for scale and governor limits

This example is intentionally simplified to teach core concepts of how agents work under the hood.

## What This Is

A minimal ReAct (Reasoning + Acting) agent that demonstrates:

- **Agent Loop**: Queueable recursion implementing Think → Act → Observe → Repeat
- **Multi-Tool Support**: Execute multiple tools per iteration with shared Unit of Work
- **Structured Output**: Parse LLM responses with Lightning Types
- **Real-Time Streaming**: Platform events for live UI updates
- **Tool Calling**: 9 example tools for Salesforce CRUD operations

## Architecture

```
User Message
    ↓
AgentController (creates session)
    ↓
AgentQueueable (iteration 1)
    ↓
Prompt Builder → LLM → AgentOutput
    ↓
[Has Answer?] → Yes → Publish & Exit
    ↓ No
Execute Tools (via ActionRouter)
    ↓
Commit DML (via AgentUnitOfWork)
    ↓
Publish Progress Event
    ↓
AgentQueueable (iteration 2) → ... → Final Answer
```

## Core Components

- **AgentQueueable** - Main agent loop (recursive Queueable)
- **AgentController** - LWC entry point
- **AgentOutput** - Structured output via Lightning Types
- **ActionRouter** - Tool dispatcher (reflection-based)
- **ToolSecurity** - Shared object/field validation
- **9 Tools** - CRUD operations, queries, search

## Project Structure

```
force-app/main/default/
├── classes/
│   ├── agent/          # Core agent logic
│   ├── tools/          # Tool implementations + shared security
│   └── utils/          # PromptService, FieldCoercion
├── lwc/agentChat/      # Chat interface with streaming
├── objects/
│   ├── AgentSession__c # Stop flag management
│   └── AgentStep__e    # Platform events for UI
└── applications/       # Lightning App package
```

## Setup (for learning/exploration)

### Quick Start

```bash
# Deploy to your default org
./bin/deploy.sh

# Or specify a target org
./bin/deploy.sh my-scratch-org
```

This will:
- Deploy all metadata
- Assign the `Agent_Chat_User` permission set to your user

### Configure Prompt Builder

After deployment, you need to set up the LLM integration:

1. **Open Setup → Prompt Builder**
2. **Create a Lightning Type** matching the `AgentOutput` class:
   - Name: `AgentOutputType`
   - Fields: `thought`, `utterance`, `answer`, `toolCalls` (all Text)
   - Copy descriptions from `AgentOutput.cls` comments
3. **Create a Prompt Template**:
   - Name: `Agentic_Template`
   - Use the `AgentOutputType` as the Output Type
   - Design your ReAct prompt (system instructions, tools, reasoning)
4. **Activate the template**

### Use the Agent

1. Open **Agent Chat** app from the App Launcher
2. Type a message and watch the agent think and act!

Example prompts:
- "Create 3 test accounts with random names"
- "Find all contacts in California"
- "Describe the Account object fields"

## What You'll Learn

- How ReAct patterns work in practice
- Queueable recursion for agent loops
- Structured output with Lightning Types
- Multi-tool execution patterns
- Real-time streaming with platform events
- Bulkified DML patterns

## Limitations (Why Use Agentforce Instead)

- **No conversation persistence** - History kept only in memory
- **Limited error recovery** - Basic try/catch, no retry logic
- **Governor limit risks** - Can hit queueable chain limits (50)
- **No observability** - Minimal logging/monitoring
- **Simplified prompt template** - Production needs more sophistication
- **Basic security** - Object/field allowlists but no full SOQL injection prevention

## License

MIT - Use for learning, not production
