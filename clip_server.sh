#!/bin/bash

set -e  # Stop on any error
set -u  # Error on undefined variables
set -o pipefail

# Define working directory
WORKDIR="$HOME/clipboard_server"
echo "[+] Using working directory: $WORKDIR"

# Create and enter the working directory
mkdir -p "$WORKDIR"
cd "$WORKDIR" || { echo "[-] Failed to enter $WORKDIR"; exit 1; }

# Check if Python is available
if ! command -v python3 &> /dev/null; then
  echo "[-] python3 not found. Please install Python 3 first."
  exit 1
fi

# Set up virtual environment if missing
if [ ! -d "venv" ]; then
  echo "[+] Creating virtual environment..."
  python3 -m venv venv || { echo "[-] Failed to create virtual environment."; exit 1; }
fi

# Activate the virtual environment
source venv/bin/activate

# Install Flask if not already installed
if ! pip show flask &> /dev/null; then
  echo "[+] Installing Flask..."
  pip install flask || { echo "[-] Failed to install Flask."; exit 1; }
else
  echo "[+] Flask already installed."
fi

# Write Python server code
echo "[+] Writing Python server code to clipboard.py"
cat <<EOF > clipboard.py
from flask import Flask, request, redirect
from collections import deque

app = Flask(__name__)
clipboard_history = deque(maxlen=5)
buffer = ""

@app.route("/", methods=["GET", "POST"])
def clipboard():
    global buffer
    if request.method == "POST":
        if "clear" in request.form:
            buffer = ""
        elif "text" in request.form:
            buffer = request.form["text"]
            clipboard_history.appendleft(buffer)

    history_items = "".join(f"<li>{item}</li>" for item in clipboard_history if item.strip())
    return f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Clipboard Sync</title>
        <style>
            :root {{
                --bg: #f0f2f5;
                --text: #000;
                --box: #fff;
                --btn-bg: #4CAF50;
                --btn-text: #fff;
                --shadow: rgba(0, 0, 0, 0.1);
            }}
            [data-theme="dark"] {{
                --bg: #121212;
                --text: #fff;
                --box: #1e1e1e;
                --btn-bg: #2196F3;
                --btn-text: #fff;
                --shadow: rgba(255, 255, 255, 0.05);
            }}
            body {{
                font-family: Arial, sans-serif;
                background: var(--bg);
                color: var(--text);
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
            }}
            .container {{
                background: var(--box);
                padding: 20px;
                border-radius: 12px;
                box-shadow: 0 0 20px var(--shadow);
                width: 90%;
                max-width: 600px;
            }}
            textarea {{
                width: 100%;
                height: 180px;
                padding: 10px;
                font-size: 16px;
                border-radius: 6px;
                border: 1px solid #ccc;
                resize: vertical;
                background: inherit;
                color: inherit;
            }}
            .buttons {{
                display: flex;
                gap: 10px;
                flex-wrap: wrap;
                margin-top: 10px;
            }}
            button {{
                padding: 10px 16px;
                font-size: 15px;
                background-color: var(--btn-bg);
                color: var(--btn-text);
                border: none;
                border-radius: 6px;
                cursor: pointer;
                flex: 1;
            }}
            button:hover {{
                opacity: 0.9;
            }}
            ul {{
                margin-top: 20px;
                padding-left: 20px;
                font-size: 14px;
            }}
            .theme-toggle {{
                text-align: right;
                margin-bottom: 10px;
            }}
            .theme-toggle button {{
                background: transparent;
                color: var(--text);
                border: 1px solid var(--text);
                font-size: 13px;
                padding: 6px 10px;
                border-radius: 5px;
            }}
        </style>
    </head>
    <body>
        <div class="container" id="main">
            <div class="theme-toggle">
                <button onclick="toggleTheme()">Toggle Dark Mode</button>
            </div>
            <form method="POST">
                <textarea name="text" placeholder="Paste or type your text here...">{buffer}</textarea>
                <div class="buttons">
                    <button type="submit">Submit</button>
                    <button type="button" onclick="copyToClipboard()">Copy to Clipboard</button>
                    <button type="submit" name="clear" value="1">Clear Clipboard</button>
                </div>
            </form>
            <ul><strong>History:</strong>{history_items}</ul>
        </div>
        <script>
            function copyToClipboard() {{
                const textarea = document.querySelector('textarea');
                textarea.select();
                document.execCommand('copy');
                alert('Copied to clipboard!');
            }}
            function toggleTheme() {{
                const current = document.documentElement.getAttribute("data-theme");
                document.documentElement.setAttribute("data-theme", current === "dark" ? "light" : "dark");
            }}
        </script>
    </body>
    </html>
    """

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

# Start the Flask server
echo "[+] Starting clipboard server at http://<your-pi-ip>:5000"
python clipboard.py