#!/usr/bin/env bash

sync_repo_token=$1
changed_paths=$2

# This separates the strings with ; to turn it into an array
IFS=';' read -ra changed_paths_array <<< "$changed_paths"
echo "Changed paths array: ${changed_paths_array[@]}"

# Configure Git
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

for path in "${changed_paths_array[@]}"; do
  # Store the current working directory
  initial_working_directory=$(pwd)

  # Extract the folder name from the path
  folder_name=$(basename $path)

  # Check if the listening repo exists
  repo="https://$sync_repo_token:@github.com/medplum/${folder_name}.git"
  REPO_STATUS=$(curl -s -o /dev/null -I -w "%{http_code}" -H "Authorization: token $sync_repo_token" "https://api.github.com/repos/medplum/${folder_name}")

  # If the repo does not exist, create a new repo
  if [ $REPO_STATUS -eq 404 ]; then
    CREATE_REPO_PAYLOAD="{\"name\": \"${folder_name}\", \"default_branch\": \"main\"}"
    CREATE_REPO_RESPONSE=$(curl -s -X POST -H "Authorization: token $sync_repo_token" -H "Content-Type: application/json" -H "Accept: application/vnd.github+json" --data "$CREATE_REPO_PAYLOAD" "https://api.github.com/orgs/medplum/repos")
    echo "Created new repo: $(echo $CREATE_REPO_RESPONSE | jq -r '.html_url')"
  fi

  # Clone the corresponding listening repo
  git clone "$repo"

  # Copy changed files to the listening repo
  rsync -a --delete --exclude .git/ --exclude tsconfig.json "${initial_working_directory}/${path%}"/ ${folder_name}/

  # Copy the LICENSE file to the listening repo
  cp LICENSE.txt ${folder_name}/

  # Commit and push changes to the listening repo
  cd ${folder_name}
  git add .
  git commit -m "Update from main medplum repo"
  git push origin main

  # Cleanup: Remove the cloned repo folder and delete the local branch
  cd ..
  rm -rf ${folder_name}
done