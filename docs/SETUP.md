# Graphical setup and addon installation

Download the archive matching your platform from [Releases](https://github.com/NermalYT/astra-mcp/releases). Extract **all** files first. The launchers open a local native window; no setup web service or public account is required.

| Platform | Open | Requirements |
| --- | --- | --- |
| Ubuntu LTS / Mint XFCE | `INSTALL_ASTRA.sh` → Run, or `bash INSTALL_ASTRA.sh` | Ordinary desktop user; Python 3, curl, xz-utils, `python3-gi`, `gir1.2-gtk-3.0`, `x-terminal-emulator` |
| Windows 11 Pro / Pro N | Double-click `INSTALL_ASTRA.cmd` | Windows PowerShell 5.1; initialized Ubuntu LTS WSL2 distribution and ordinary Linux user |

Click **Install / upgrade Astra**. A terminal opens for dependency progress and any sudo password. The window reports success/failure. On Windows, select the exact installed WSL distribution name first. Restart LM Studio after success, load a tool-capable model and enable **mcp/astra**. No model or commercial studio app is bundled.

This is a **one-launch graphical installer**, not an unattended operating-system installer. Initial WSL installation, reboot/account setup, OS security prompts, archive extraction and dependency authentication can require user action. Windows configuration and your old source copy are preserved for rollback. Linux setup retains the final 30,000 characters of terminal output in the window; Windows failures retain their console.

If Linux GTK bindings are missing, the launcher falls back to the terminal installer. To install the GUI requirements:

```bash
sudo apt-get update
sudo apt-get install python3 curl xz-utils python3-gi gir1.2-gtk-3.0 x-terminal-emulator
```

For terminal automation use `bash INSTALL_ASTRA.sh --no-gui` on Linux. Set `ASTRA_NO_GUI=1` on Windows or pass explicit installer arguments. `ASTRA_NO_PAUSE=1` suppresses the terminal launcher's final pause. A custom LM Studio config path requires the CLI; the Windows addon window reads the default `%USERPROFILE%\.lmstudio\mcp.json`.

## Install an addon

1. Download an addon from a source you trust and extract its ZIP if applicable. Review its source and access requirements. The picker accepts an **extracted folder**, not a ZIP or remote URL.
2. Reopen the same Astra launcher. Choose **Install addon…**, select the folder directly containing `astra-addon.json`, and review the inspection result.
3. Click **OK** to install that trusted addon. This copies it into your private Astra data directory. Restart Astra (toggle its MCP connection off/on or restart LM Studio) to load it.

Use **My addons** to view installed entries. A matching ID is never silently overwritten. Use the documented addon CLI or `astra_addons` tool to disable, remove or replace an addon. Addon installation does not install third-party dependencies automatically; an author must declare preparation steps. Folder picking plus explicit trust confirmation is intentional: addons can execute code as your account. Nothing is uploaded by these buttons.

To try the bundled example, choose `examples/hello-addon`, install it, restart Astra, and discover `hello__greet`. See [making and submitting addons](ADDONS.md) and the [community section](../addons/README.md).

The GUI is a setup utility; the separate `astra_control_panel` tool opens the live desktop/activity panel while Astra is running.

Optional studio templates are included in `examples/roblox-studio-addon` and `examples/unity-cli-addon`. Prepare the vendor software first and read each template README; installing a launcher does not establish a verified live connection.
