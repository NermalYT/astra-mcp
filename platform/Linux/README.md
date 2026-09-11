# Start here: Astra for Linux

This archive is for Ubuntu 22.04, 24.04, or 26.04 LTS and derivatives that declare one of those Ubuntu bases, such as Linux Mint XFCE. It targets x86-64 and ARM64. See [platform validation status](../../docs/PLATFORMS.md); a supported target is not a claim of testing every machine.

## Install

1. Extract the entire `Astra-3.0.0-Linux-Ubuntu-LTS.tar.gz` archive.
2. Install Python 3, curl, and xz utilities if missing:

   ```bash
   sudo apt-get update
   sudo apt-get install python3 curl xz-utils python3-gi gir1.2-gtk-3.0 x-terminal-emulator
   ```

3. Double-click `INSTALL_ASTRA.sh` and choose **Run** to open graphical setup, then click **Install / upgrade Astra**. If your file manager opens scripts in an editor, open a terminal in the extracted directory and run as your ordinary user:

   ```bash
   bash INSTALL_ASTRA.sh
   ```

   In a source checkout the equivalent launcher is `bash platform/Linux/INSTALL_ASTRA.sh`.

   The setup window also provides **Install addon…** and **My addons**. See [graphical setup](../../docs/SETUP.md). Missing GTK falls back to the terminal installer.

4. Restart LM Studio, choose a model with working tool calling, and enable **mcp/astra**. Ask the model to call `astra_status`, then `astra_help`.

The launcher stages a fresh installed copy under `~/.local/share/astra-mcp/sources/`, installs missing Node 22 privately when needed, installs Linux/browser dependencies using `sudo`, and verifies MCP startup before registration. Internet access is needed for dependencies; no model, Blender, Unity, or GPU driver is bundled. The terminal retains errors and waits for Enter when interactive. Set `ASTRA_NO_PAUSE=1` for scripted use.

The installer backs up existing `~/.lmstudio/mcp.json`, replaces the Astra entry, removes the six original Astra backend registrations, and preserves unrelated MCP entries. Old installed source copies and browser data remain. To use a different host configuration file, append `--config /absolute/path/mcp.json`. For a customized installation, use `scripts/install.sh` options directly; see [installation and rollback](../../docs/PLATFORMS.md).

## Start a workflow and open the panel

Astra 3 provides all 99 tools through five compact entry tools by default. Ask the model to use `astra_tools` to discover exact schemas, then `astra_call` to perform the task. Full mode is available through `ASTRA_TOOL_MODE=full` in the Linux launch environment or `"tool_mode":"full"` in settings; restart Astra after changing it.

Call `astra_control_panel` and open its private session link to see activity, jobs and local workers. Its optional two-second desktop viewer is read-only and pauses polling when hidden. Pause blocks new controlled calls; Stop additionally requests cancellation of active work. Neither undoes completed actions or creates a security sandbox. With Node/npm available, `npm run control` from an Astra source directory in Linux/WSL prints the active link. Keep that link private.

Project tools provide bounded search/read and hash-checked literal edits. `astra_workspace_notes` saves explicit project checkpoints across restarts; ask the next session to read them. `astra_agent_start` is optional and needs a running loopback model API plus a model/tool whitelist; normal MCP use needs no separate API. See [studio workflows](../../docs/STUDIO.md) for exact arguments and limits.

## What runs independently

Astra uses its own Linux display, cursor, keyboard focus, clipboard, application profiles, and hidden Chromium browser. It can read its loaded tabs while you work fullscreen. It does not import your personal browser tabs, reveal content a site has not loaded, or create a second cursor inside the same personal application window.

Xvfb is a virtual display, not a promise of hardware-accelerated 3D. Use [studio jobs and project workflows](../../docs/STUDIO.md) for Blender scripts, renders, and build commands. Files remain subject to the launching user's permissions; the private desktop is not a security sandbox.

## Verify or restore

Compare the archive's SHA-256 with `SHA256SUMS` from the release before extracting. Each package contains `RELEASE_MANIFEST.json`; the maintainer's packaging command validates archive contents and a fresh extraction against it. Hashes detect corruption and do not replace trusting the release source.

To roll back, close LM Studio and restore a chosen adjacent `mcp.json.backup-*` file as `mcp.json`, then restart LM Studio. Keep the source copy referenced by that backup. Browser sessions are retained under `~/.local/share/astra-mcp`; source rollback does not roll back those sessions.

The full project overview remains in [README.md](../../README.md). Model selection and a basic compatibility check are described in [MODELS.md](../../docs/MODELS.md).
