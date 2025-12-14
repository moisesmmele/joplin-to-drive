# joplin-to-drive
A Dockerized pipeline that automatically exports and syncs Joplin notes to Google Drive to enable personal knowledge base integration with Gemini.
## Overview

This project provides a "set-and-forget" solution for Joplin users who want to leverage Large Language Models (specifically Google Gemini) with their personal notes.

While Joplin is excellent for privacy and self-hosting, current "RAG" (Retrieval-Augmented Generation) solutions often require complex vector database pipelines. This project takes a pragmatic approach: it periodically exports your notes to standard Markdown and pushes them to a private Google Drive folder. This allows you to use the Gemini workspace extensions to query, summarize, and interact with your personal knowledge base without manual file handling.

## How It Works

This container performs the following ETL operations on a customizable cron schedule:
1.  **Sync:** Synchronizes with your self-hosted Joplin Server using the `joplin` CLI.
2.  **Export:** Exports notes to a local directory in standard Markdown format.
3.  **Push:** Uses `rclone` to sync the exported Markdown files to a specific Google Drive folder.

## Prerequisites

* **Docker & Docker Compose** installed on your host machine.
* **Rclone** installed on your host machine (only required once for generating the authentication token).
* **Self-hosted Joplin Server** instance.

## Setup & Configuration

### 1. Google Drive Authentication
Because the container runs headless, you must generate the `rclone.conf` file on your host machine first using the provided helper script.

1.  Ensure you have `rclone` installed locally.
2.  Run the helper script:
    ```bash
    chmod +x scripts/helper-script.sh
    ./scripts/helper-script.sh
    ```
3.  Follow the browser authentication flow.
4.  The script will automatically save the necessary credentials to `./config/rclone.conf`.

### 2. Environment Variables
Create a `.env` file based on the example:

```bash
cp .env-example .env
```

Edit `.env` with your actual Joplin credentials. **Note:** The variable names below must match exactly for the script to work.

| Variable | Description | Default |
| :--- | :--- | :--- |
| `JOPLIN_SERVER_URL` | The URL of your Joplin Server (e.g. `http://192.168.1.50:22300`) | - |
| `JOPLIN_SERVER_EMAIL` | Your Joplin account email | - |
| `JOPLIN_SERVER_PASSWORD` | Your Joplin account password | - |
| `JOPLIN_SYNC_TARGET_ID` | Sync target ID (usually `9` for Joplin Server) | `9` |
| `RCLONE_REMOTE_NAME` | Must match the remote name in rclone.conf (helper sets this to `gdrive`) | `gdrive` |
| `RCLONE_DEST_PATH` | The folder path on Google Drive | `JoplinNotes` |

### 3. Schedule Configuration (Cron)
The schedule is controlled by the `scripts/joplin-cron` file.

1.  Open `scripts/joplin-cron`.
2.  Modify the cron expression to your desired frequency.
    * *Default (Every 5 minutes):* `*/5 * * * * ...`
    * *Example (Every hour):* `0 * * * * ...`

**Note:** If you change the schedule, you must restart the container for the changes to take effect.

## Deployment

Start the service using Docker Compose:

```bash
docker-compose up -d
```

### Viewing Logs
To verify the sync is working, check the container logs:

```bash
docker logs -f joplin_sync
```

You should see output indicating the 3 stages:
1.  `Syncing Joplin from Server...`
2.  `Exporting to Markdown...`
3.  `Pushing to Google Drive...`

## Privacy Note
**Warning:** This tool explicitly moves data from a self-hosted environment to a third-party cloud provider (Google Drive). Ensure you are comfortable with the privacy implications. It is recommended to configure Joplin to exclude sensitive notebooks (like passwords or financial data) from the sync profile if possible, or use a separate Joplin profile for "public/AI" notes.
