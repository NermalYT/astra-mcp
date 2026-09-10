# Customize Astra with addons

An addon adds tools to your installed Astra without editing Astra's core source. It runs as a local MCP server behind the same **astra** integration. You keep one switch in LM Studio or another compatible MCP host; you do not register every addon as another host integration.

Start with the [included hello addon](../examples/hello-addon). Find or share optional extensions in the [community addon area](../addons/README.md). Addons stay private unless you explicitly publish them there or elsewhere.

## Install an addon you trust

1. Obtain the source from its author. If it is a ZIP or other archive, extract it into a local directory and inspect its contents. Astra's addon installer accepts a directory, not a URL or archive.
2. Read the manifest, server code, README and license. Review dependencies, file/process access, network use and setup commands. A manifest and valid tool schema do not make code safe.
3. Open a Linux terminal, or your Astra Ubuntu WSL terminal on Windows, in your installed Astra source directory. Inspect the addon without running its server:

   ```bash
   node scripts/addons.mjs inspect /path/to/addon
   ```

4. Review the addon's dependency setup instructions. Astra does not download dependencies or execute installation scripts for you. Use the application/runtime inside Linux or WSL unless the addon explicitly documents another arrangement.
5. Install and enable the reviewed source:

   ```bash
   node scripts/addons.mjs install /path/to/addon --trust
   node scripts/addons.mjs list
   ```

6. Complete the reviewed dependency setup before the next Astra start. If setup writes dependencies inside the addon, use the installed path returned by the previous command. Restart the Astra integration through your MCP host. Source is loaded at process start. Ask the model to discover the addon's tools, then run its documented harmless smoke test.

The installer copies source into `ASTRA_DATA_DIR/addons/installed/ADDON_ID`, normally `~/.local/share/astra-mcp/addons/installed/ADDON_ID`. Use the same `ASTRA_DATA_DIR` as the running service if you changed it. The copied directory does not follow later edits to the original. Installation accepts at most 1,000 regular files, 2 MiB per file, 20 MiB total, 200 directories and 16 directory levels. It rejects symlinks, hardlinks, special files and a `.git` directory; remove repository history from the source package before inspecting it. At most 64 addons can be registered.

The `--trust` flag records your decision to run that local code; it is not a security audit or sandbox. Addons run with your user's access and can read files, start processes or use the network according to their code. The private desktop environment helps separate desktop interaction; it does not isolate files or network access.

## Manage addons through your model

Ask a compatible tool-capable model:

> Read Astra's addon guide and discover `astra_addons`. Inspect the addon at [absolute Linux or WSL path], explain what it executes and what setup it needs, and install it for my local Astra once that matches my request. Keep the addon and edits private. Run its checks and tell me how to activate it. Finish your response before restarting anything that would disconnect this conversation.

Call `astra_tools` with `{"names":["astra_addons"]}` for the actual installed management schema. The same inspect, install, list, enable, disable and remove operations are available through that tool. In compact mode, invoke a discovered operation with `astra_call` using the original tool's arguments. Installing or enabling requires an explicit `trust:true` argument after the user has requested running the addon.

For example, inspect the copied hello source through compact mode:

```json
{"tool":"astra_addons","arguments":{"action":"inspect","path":"/absolute/path/to/hello-addon"}}
```

After reviewing it and deciding to run it, installation uses:

```json
{"tool":"astra_addons","arguments":{"action":"install","path":"/absolute/path/to/hello-addon","trust":true}}
```

After restarting, discover `hello__greet` and call:

```json
{"tool":"hello__greet","arguments":{"name":"Astra user"}}
```

The default compact interface still advertises five entry tools. Search by the addon's identifier or purpose with `astra_tools`, retrieve its schema, then call the namespaced tool through `astra_call`. Full mode also advertises the enabled addon's tools directly. The catalog grows according to the addons successfully loaded in that session; the core release's tool count is not the installed total.

`astra_addons` list shows the configured inventory and any manifest errors; `enabled:true` alone does not prove a server is running. After restart, verify runtime/backend status with `astra_status` and check that the expected tools appear in discovery. If they do not, inspect startup diagnostics, dependencies and the addon's documented platform requirements. Disable a broken addon from the terminal and restart to recover core operation.

## Disable or remove

Use the manifest's addon identifier:

```bash
node scripts/addons.mjs disable ADDON_ID
node scripts/addons.mjs enable ADDON_ID --trust
node scripts/addons.mjs remove ADDON_ID
```

Restart Astra after a change. Disabling removes the addon from the next session's active set; it does not terminate an already running server in the current session. Removal retains a recoverable copy in the private addons trash directory. It does not undo files, application changes, external activity or separately installed dependencies created by that addon. Close the host's Astra session if you need its current addon server to stop before restarting.

To replace an installed version, preserve any local edits, stop Astra, remove the registered addon to private trash, inspect the replacement source, install it with `--trust`, then start Astra and verify it. Installing the same identifier over an existing registration is refused. To recover a removed version, inspect and install the returned `recovery_path`; first remove any replacement registered under the same identifier. Keep the recovery copy until the replacement works.

## Build your own

The runnable [hello addon](../examples/hello-addon) is a complete, dependency-free starting point. Copy its directory somewhere private, rename its manifest identifier and tool, and adapt its server. Keep a README and a license with your addon.

Create `astra-addon.json` at the top of the addon directory:

```json
{
  "id": "hello",
  "name": "Hello Astra",
  "version": "1.0.0",
  "description": "A local greeting tool with no external dependencies.",
  "astra_compat": ">=3.0.0 <4.0.0",
  "platforms": ["linux", "windows-wsl2"],
  "server": {
    "command": "{node}",
    "args": ["{addon}/server.mjs"]
  }
}
```

| Field | Contract in Astra 3 |
| --- | --- |
| `id` | 1–32 lowercase letters, digits or underscores, beginning with a letter. `astra` and identifiers starting `astra_` are reserved. |
| `name`, `description` | Short display name and an accurate explanation of the addon. |
| `version` | Addon version such as `1.0.0`; update it when distributing a changed addon. |
| `astra_compat` | Exactly `>=3.0.0 <4.0.0` in this release's manifest format. |
| `platforms` | One or both of `linux` and `windows-wsl2`. Declare only platforms your addon supports; Windows means the supported Ubuntu WSL environment. |
| `server.command` | Executable name or path. `{node}` expands to Astra's current Node executable. |
| `server.args` | Array of literal command arguments. `{addon}` expands to the installed addon directory. No shell command string is required. |
| `server.env` | Optional string-to-string environment entries for this server; the same two placeholders expand here. Keep secret values out of distributed manifests. |

Unknown manifest and server fields are rejected. The server starts with its installed directory as its working directory. For a Python addon, use an available Python executable and its script path in `args`; document how the user prepares that interpreter and its dependencies. Large runtimes, model weights and application assets should be installed separately, with explicit local configuration, because the addon directory is a bounded source package.

An addon server implements MCP over standard input/output. Keep protocol output on stdout and human diagnostics on stderr. Publish focused tools with precise JSON schemas, clear descriptions and useful errors. Validate inputs, bound output and long-running work, and implement cancellation where operations permit it. Tool descriptions help a model choose correctly; text from a web page or tool result cannot authorize extra actions.

Tool names are prefixed with the manifest identifier: an addon `hello` exposing `greet` becomes `hello__greet` in Astra. The combined name must contain at most 64 letters, digits, underscores or hyphens. Namespacing keeps addon tools separate from core and other addon tools. It does not restrict what the underlying program can do. Astra integrates tools; do not assume an addon's own resources, prompts, browser interface or remote authentication are forwarded automatically.

Test the server directly, inspect the addon, install your local copy, restart Astra, discover its exact schema and call it through the host. Test failed inputs and any material effects, not just a successful greeting. Confirm behavior with the host/model versions you intend to support. A model that handles core tool calls may still struggle with a poorly described addon or fail to interpret images.

For private iteration, use `astra_addons` list to obtain the installed path, back up that directory, edit its source with the project tools, run the addon's tests and restart Astra. Keep its manifest identifier consistent with the installed directory. Source maintenance backups cover Astra's core, so separately preserve addon code and configuration before changing them. No reinstall is needed for edits to the installed copy.

## Release an optional community addon

Provide source, an exact version, an install/remove guide, dependencies, an example request, a harmless verification step, known limitations and license terms. State Windows/WSL or Linux requirements and actual tested model/host combinations. Do not claim compatibility with every model or native Windows desktop control without evidence.

Publish through the [addon submission form](https://github.com/NermalYT/astra-mcp/issues/new?template=addon.yml). Link inspectable source and a versioned download, or attach a source ZIP. Include a SHA-256 for the exact archive. A submission becomes a public community listing; it is not automatically installed, merged into a release or certified by Astra.

For private changes, simply keep working locally. Neither addon installation nor [source maintenance](UPGRADING.md) uploads code, pushes Git commits or opens a pull request. If your chosen model runs in the cloud, source you ask it to read may still be sent through that model host.
