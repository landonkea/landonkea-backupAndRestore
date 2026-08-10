# landonkea-backupAndRestore - Design & Workflow

## High-Level Overview

```mermaid
graph TB
    subgraph "landonkea-backupAndRestore"
        A[backup.sh] --> B[Backup folder]
        C[restore.sh] --> D[Restore from folder]
    end

    subgraph "What gets backed up"
        E[Homebrew packages]
        F[npm global packages]
        G[pip packages]
        H[Ruby gems]
        I[Dotfiles]
        J[SSH keys]
    end

    A --> E
    A --> F
    A --> G
    A --> H
    A --> I
    A --> J
```

## Backup Workflow

```mermaid
sequenceDiagram
    participant U as User
    participant B as backup.sh
    participant H as Homebrew
    participant N as npm
    participant P as pip
    participant R as RubyGems
    participant F as Filesystem

    U->>B: Run backup.sh
    B->>H: brew bundle dump
    H-->>B: Brewfile
    B->>N: npm list -g --depth=0
    N-->>B: npm-packages.txt
    B->>P: pip freeze
    P-->>B: requirements.txt
    B->>R: gem list
    R-->>B: Gemfile
    B->>F: Copy dotfiles
    B->>F: Copy SSH keys
    B-->>U: Backup folder created
```

## Restore Workflow

```mermaid
sequenceDiagram
    participant U as User
    participant R as restore.sh
    participant H as Homebrew
    participant N as npm
    participant P as pip
    participant Rb as RubyGems
    participant F as Filesystem

    U->>R: Run restore.sh
    R->>H: brew bundle
    H-->>R: Packages installed
    R->>N: npm install -g
    N-->>R: Packages installed
    R->>P: pip install -r
    P-->>R: Packages installed
    R->>Rb: bundle install
    Rb-->>R: Gems installed
    R->>F: Copy dotfiles
    R->>F: Copy SSH keys
    R-->>U: Restore complete
```

## File Relationships

| File | Purpose | Used By |
|------|---------|---------|
| `backup.sh` | Create backup | User |
| `restore.sh` | Restore from backup | User |
| `Mac_Backup_*/` | Backup data | `restore.sh` |

## draw.io

[Open in draw.io](https://app.diagrams.net/#RBackup%20restore%20workflow)
