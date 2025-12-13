# joplin-to-drive
A Dockerized pipeline that automatically exports and syncs Joplin notes to Google Drive to enable personal knowledge base integration with Gemini.
## Overview

This project provides a "set-and-forget" solution for Joplin users who want to leverage Large Language Models (specifically Google Gemini) with their personal notes.

While Joplin is excellent for privacy and self-hosting, current "RAG" (Retrieval-Augmented Generation) solutions often require complex vector database pipelines. This project takes a pragmatic approach: it periodically exports your notes to standard Markdown and pushes them to a private Google Drive folder. This allows you to use the Gemini workspace extensions to query, summarize, and interact with your personal knowledge base without manual file handling.

## How It Works

The container performs the following ETL (Extract, Transform, Load) operations on a cron schedule:

1.  **Sync:** The internal `joplin-cli` client synchronizes with your self-hosted Joplin Server to fetch the latest state.
2.  **Export:** Notes are exported to a local directory in `md_frontmatter` format (preserving tags and metadata).
3.  **Sanitize:** (Optional) Basic regex cleaning to ensure links and structure are LLM-friendly.
4.  **Push:** `rclone` synchronizes the exported directory with a specified Google Drive path.

## Prerequisites

* **Self-hosted Joplin Server** (or a synced Joplin instance).
* **Docker & Docker Compose** installed on your host machine.
* **Google Account** with Drive access.
* **Rclone Config:** You must generate an `rclone.conf` file locally first, as the Google Drive OAuth flow requires a browser.

## Configuration

### 1. Rclone Setup
Since the container is headless, you need to generate the configuration file on your local machine:
```bash
# Run on your local machine
rclone config
# Select 'New remote', choose 'drive', and follow the OAuth authentication flow.
# Name the remote 'gdrive' (or update the script accordingly).
```
Save the resulting `rclone.conf`. You will mount this file into the container.

### 2. Environment Variables
Create a `.env` file or define these in your compose file:

| Variable | Description | Default |
| :--- | :--- | :--- |
| `JOPLIN_BASE_URL` | URL of your Joplin Server | `http://your-joplin-server:22300` |
| `JOPLIN_EMAIL` | User email for login | - |
| `JOPLIN_PASSWORD` | User password for login | - |
| `SYNC_INTERVAL` | Cron schedule expression | `0 */6 * * *` (Every 6 hours) |
| `DRIVE_DEST_PATH` | Destination path on Google Drive | `gdrive:/JoplinNotes` |

## Docker Compose Example

```yaml
version: '3.8'

services:
  joplin-to-drive:
    image: yourusername/joplin-to-drive:latest
    container_name: joplin_rag_sync
    restart: unless-stopped
    environment:
      - JOPLIN_BASE_URL=http://192.168.1.50:22300
      - JOPLIN_EMAIL=myuser@example.com
      - JOPLIN_PASSWORD=securepassword
      - SYNC_INTERVAL="0 */4 * * *" # Run every 4 hours
      - DRIVE_DEST_PATH=gdrive:/AI_Knowledge_Base
    volumes:
      - ./config/rclone.conf:/root/.config/rclone/rclone.conf:ro
      - ./data/joplin-config:/root/.config/joplin # Persist joplin-cli state
```

## Privacy Note
**Warning:** This tool explicitly moves data from a self-hosted environment to a third-party cloud provider (Google Drive). Ensure you are comfortable with the privacy implications. It is recommended to configure Joplin to exclude sensitive notebooks (like passwords or financial data) from the sync profile if possible, or use a separate Joplin profile for "public/AI" notes.
