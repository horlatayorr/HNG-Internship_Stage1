#!/bin/bash

# Check if running as root
if [[ $UID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Define the input file, log file, and secure password file
INPUT_FILE="$1"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Check if the input file was provided and exists
if [[ -z "$INPUT_FILE" ]]; then
   echo "No input file provided."
   exit 1
fi
if [[ ! -f "$INPUT_FILE" ]]; then
   echo "File $INPUT_FILE not found."
   exit 1
fi

# Create the log file and password file if they don't exist
touch "$LOG_FILE"
mkdir -p /var/secure
touch "$PASSWORD_FILE"

# Function to generate a random password
generate_password() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Function to log messages
log_message() {
  echo "$1" | tee -a "$LOG_FILE"
}

log_message "Backing up created files"
# Backup existing files
cp "$PASSWORD_FILE" "${PASSWORD_FILE}.bak"
cp "$LOG_FILE" "${LOG_FILE}.bak"

# Set permissions for password file
chmod 600 "$PASSWORD_FILE"

# Read the input file line by line
while IFS=';' read -r username groups || [[ -n "$username" ]]; do
   # Ignore whitespace
  username=$(echo "$username" | sed 's/ //g')
  groups=$(echo "$groups" | sed 's/ //g')

  # Parse the username and groups
  echo "$username"
  echo "$groups"

  # Create the user and their personal groups if they don't exist
  if id "$username" &>/dev/null; then
      log_message "User $username already exists. Skipping..."
  else
      # Create personal groups for the user
      groupadd "$username"
      # Create user with their personal groups
      useradd -m -s /bin/bash -g "$username" "$username"
      if [ $? -eq 0 ]; then
          log_message "User $username created with home directory."
      else
          log_message "Failed to create user $username."
          continue
      fi
      # Generate a random password and set it for the user
      PASSWORD=$(generate_password)
      echo "$username,$PASSWORD"
      if [ $? -eq 0 ]; then
          log_message "Password for user $username set."
      else
          log_message "Failed to set password for user $username."
      fi
      # Store the password securely
      echo "$username,$PASSWORD" >> "$PASSWORD_FILE"
      # Set the correct permissions for the home directory
      chmod 700 /home/"$username"
      chown "$username":"$username" /home/"$username"
      log_message "Home directory permissions set for user $username."
  fi

  # Add user to additional groups
  if [ -n "$groups" ]; then
      IFS=',' read -r -a groups_ARRAY <<< "$groups"
      for groups in "${groups_ARRAY[@]}"; do
          # Create groups if it doesn't exist
          if ! getent group "$groups" > /dev/null 2>&1; then
              groupadd "$groups"
              log_message "group $groups created."
          fi
          # Add user to the groups
          usermod -a -G "$groups" "$username"
          if [ $? -eq 0 ]; then
              log_message "User $username added to groups $groups."
          else
              log_message "Failed to add user $username to groups $groups."
          fi
      done
  fi
done < "$INPUT_FILE"
log_message "User creation process completed."