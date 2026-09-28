# CODESYS MCP Server Reference

## What the official product is

The official product is named **CODESYS Development System MCP Server**. It exposes an MCP interface from the CODESYS Development System to an MCP-capable LLM client. The official product page lists requirements around CODESYS Development System V3.5.22.1 or newer and a CODESYS Professional Developer Edition subscription/license.

The current product should not be described loosely as “the CODESYS 4 MCP.” CODESYS 4 is a separate web-based/file-based engineering generation, while the MCP Server documentation and store requirements are centered on the CODESYS Development System and the V3.5 product line. CODESYS 4 is designed for direct file access and CLI automation; native multi-step agent workflows are a related direction, not proof that every MCP tool already targets CODESYS 4.

## Capabilities

Officially documented capabilities include:

- browse the project tree or a subtree;
- read Structured Text content;
- create or modify data types and POUs using Structured Text;
- perform targeted text replacement in Structured Text objects;
- read device and I/O configuration;
- access compact library documentation;
- run compiler/error checks and retrieve diagnostics;
- interact with online/controller functions where the installed product and permissions support them;
- add custom tools for SDK customers in MCP Server 1.1.0.0.

The current documented creation/modification scope is primarily Structured Text. Graphical objects such as Ladder Diagram, FBD, and SFC may be readable but should not be assumed to be creatable or editable through the initial MCP tool set. Device configuration, visualization generation, and full autonomous commissioning are separate capabilities and require explicit verification.

## Runtime architecture

```text
LLM client (Claude / ChatGPT / Copilot / custom MCP client)
                │ MCP
                ▼
CODESYS Development System MCP Server
                │ in-process engineering API
                ▼
CODESYS project, compiler, libraries, device/configuration services
```

The MCP server is an IDE-integrated bridge. It is useful when the agent needs semantic project-tree operations, compiler diagnostics, library documentation, or controlled IDE operations. It is not a replacement for `c4-cli` in a clean CI runner.

## CODESYS 4 agent architecture

For a CODESYS 4-focused PLC agent, use a hybrid design:

```text
MCP client / LLM
       │
       ├── CODESYS MCP Server: semantic IDE operations where supported
       │
       ├── filesystem tools: edit .fbslib/.fbsdev, ST, JSON, lockfiles
       │
       └── c4-cli: resolve, check, compile, package, and collect diagnostics
```

Recommended policy:

1. Use MCP for project-aware inspection, explanations, library documentation, and controlled edits when the target is supported.
2. Use file-based edits and `c4-cli` for reproducible CODESYS 4 CI/CD.
3. Treat compilation as a mandatory tool-gated step after every generated-code change.
4. Keep controller login, download, start, and online monitoring in a separate authorization boundary.
5. Record the MCP server version, CODESYS version, compiler version, project path, changed files, diagnostics, and artifact hash.

## Licensing and operational constraints

- The official MCP Server is distributed through the CODESYS Installer.
- A Professional Developer Edition license/subscription is required according to the product documentation.
- Only one MCP Server instance can be enabled at a time in the documented command path.
- The server must be explicitly enabled before an MCP client can connect.
- The documented programmatic toggle is the command `['ai_engineering_tools', 'enable_mcp_stdio', true]`.
- Do not expose an online controller tool to an autonomous agent by default.

## Official references

- [CODESYS Development System MCP Server product page](https://www.codesys.com/ecosystem/release-lifecycle/releases-updates/development-system-mcp-server/)
- [CODESYS MCP Server documentation](https://content.helpme-codesys.com/en/CODESYS%20Development%20System%20MCP%20Server/index.html)
- [MCP Server store requirements](https://us.store.codesys.com/codesys-mcp-server.html)
- [Enable MCP Server command](https://content.helpme-codesys.com/en/CODESYS%20Development%20System%20MCP%20Server/_idemcp_cmd_enable_mcp_server.html)
- [CODESYS AI-supported Engineering](https://www.codesys.com/products/engineering/ai-supported-engineering/)
