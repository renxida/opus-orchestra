import * as vscode from 'vscode';

/**
 * Unified path handling for cross-platform compatibility.
 *
 * The extension runs on Windows Node.js but may execute commands in WSL, Git Bash, etc.
 * This class ensures paths are always converted to the correct format for each context.
 *
 * Path contexts:
 * - nodeFs: For Node.js fs operations (always Windows format on Windows)
 * - terminal: For terminal commands (WSL: /mnt/c/..., Git Bash: /c/..., Windows: C:\...)
 * - display: For showing to users (Windows format)
 */
export class AgentPath {
    private readonly originalPath: string;
    private readonly drive: string;
    private readonly restPath: string;

    constructor(inputPath: string) {
        this.originalPath = inputPath;

        // Parse the path to extract drive and rest
        const wslMatch = inputPath.match(/^\/mnt\/([a-z])\/(.*)/i);
        const gitBashMatch = inputPath.match(/^\/([a-z])\/(.*)/i);
        const windowsMatch = inputPath.match(/^([a-zA-Z]):[\\\/](.*)/);

        if (wslMatch) {
            this.drive = wslMatch[1].toLowerCase();
            this.restPath = wslMatch[2].replace(/\\/g, '/');
        } else if (windowsMatch) {
            this.drive = windowsMatch[1].toLowerCase();
            this.restPath = windowsMatch[2].replace(/\\/g, '/');
        } else if (gitBashMatch && !inputPath.startsWith('/mnt/')) {
            this.drive = gitBashMatch[1].toLowerCase();
            this.restPath = gitBashMatch[2].replace(/\\/g, '/');
        } else {
            // Unknown format - assume it's a relative path or unix path without drive
            this.drive = '';
            this.restPath = inputPath.replace(/\\/g, '/');
        }
    }

    /**
     * Get path for Node.js fs operations.
     * Always returns Windows format (C:/...) since the extension runs on Windows.
     */
    forNodeFs(): string {
        if (!this.drive) {
            return this.restPath;
        }
        return `${this.drive.toUpperCase()}:/${this.restPath}`;
    }

    /**
     * Get path for terminal commands based on the configured terminal type.
     */
    forTerminal(): string {
        const terminalType = vscode.workspace.getConfiguration('claudeAgents')
            .get<string>('terminalType', 'wsl');

        if (!this.drive) {
            // Unix path without drive letter (macOS/Linux) - return as-is
            return this.restPath.startsWith('/') ? this.restPath : `/${this.restPath}`;
        }

        switch (terminalType) {
            case 'wsl':
                return `/mnt/${this.drive}/${this.restPath}`;
            case 'gitbash':
                return `/${this.drive}/${this.restPath}`;
            case 'bash':
                // Native bash (macOS/Linux) - shouldn't have drive letters, but handle gracefully
                return `/${this.restPath}`;
            case 'powershell':
            case 'cmd':
                return `${this.drive.toUpperCase()}:\\${this.restPath.replace(/\//g, '\\')}`;
            default:
                return this.forNodeFs();
        }
    }

    /**
     * Get path for display to users (Windows format).
     */
    forDisplay(): string {
        if (!this.drive) {
            return this.restPath;
        }
        return `${this.drive.toUpperCase()}:\\${this.restPath.replace(/\//g, '\\')}`;
    }

    /**
     * Join a subpath to this path, returning a new AgentPath.
     */
    join(...parts: string[]): AgentPath {
        const joined = [this.forNodeFs(), ...parts].join('/').replace(/\/+/g, '/');
        return new AgentPath(joined);
    }

    /**
     * Get the original path as provided.
     */
    toString(): string {
        return this.originalPath;
    }
}

/**
 * Create an AgentPath from any path format.
 */
export function agentPath(inputPath: string): AgentPath {
    return new AgentPath(inputPath);
}
