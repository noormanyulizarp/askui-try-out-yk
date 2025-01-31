#!/bin/bash

# Set the target directory
TARGET_DIR="$HOME/Ai"

# Ensure the target directory exists
mkdir -p "$TARGET_DIR"

# Check if the Hugging Face token is set
if [ -z "$HUGGINGFACE_TOKEN" ]; then
  echo "Error: HUGGINGFACE_TOKEN is not set. Please set it in your Gitpod environment."
  exit 1
fi

# Install dependencies (only if not installed)
pip install --quiet transformers requests jq || {
  echo "Error installing dependencies."
  exit 1
}

# Create the Python script for BLOOM API
cat <<EOF > "$TARGET_DIR/bloom_api.py"
import os
import sys
import requests
import json

API_URL = "https://api-inference.huggingface.co/models/bigscience/bloom"
HEADERS = {"Authorization": f"Bearer {os.getenv('HUGGINGFACE_TOKEN')}"}

def generate_text(prompt):
    response = requests.post(API_URL, headers=HEADERS, json={"inputs": prompt})
    return response.json()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: bloom_help \"Your question or text\"")
        sys.exit(1)

    prompt = " ".join(sys.argv[1:])
    result = generate_text(prompt)

    if isinstance(result, list) and "generated_text" in result[0]:
        print(result[0]["generated_text"])
    else:
        print(json.dumps(result, indent=2))  # Print full response if unexpected
EOF

# Create a shell script wrapper for easy CLI usage
cat <<EOF > "$TARGET_DIR/bloom_help"
#!/bin/bash
python3 "$TARGET_DIR/bloom_api.py" "\$@"
EOF

# Make the script executable
chmod +x "$TARGET_DIR/bloom_help"

# Add an alias for easy access (only if not already present)
if ! grep -q 'alias bloom_help=' ~/.zshrc; then
  echo 'alias bloom_help="$HOME/Ai/bloom_help"' >> ~/.zshrc
  echo "Alias added to ~/.zshrc. Please run: source ~/.zshrc"
else
  echo "Alias already exists in ~/.zshrc."
fi

echo "BLOOM is now ready! Use it like this:"
echo 'bloom_help "Please explain this code: <HTML>"'
