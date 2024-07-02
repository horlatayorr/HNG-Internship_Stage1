#!/bin/bash

# Check if the input file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <name-of-text-file>"
  exit 1
fi

INPUT_FILE=$1
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Create the necessary directories and set permissions
mkdir -p /var/secure
touch $LOG_FILE $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Function to log messages
log_message() {
  echo "$(date +"%Y-%m-%d %T") - $1" >> $LOG_FILE
}

# Function to generate random passwords
generate_password() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Read the input file line by line
while IFS=';' read -r username groups; do
  # Trim whitespace
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)

  # Check if the line is empty
  if [ -z "$username" ]; then
    log_message "Empty or malformed line skipped."
    continue
  fi

  # Check if the user already exists
  if id "$username" &>/dev/null; then
    log_message "User $username already exists."
    continue
  fi

  # Create the user's personal group
  groupadd "$username"

  # Create the user with the personal group
  useradd -m -g "$username" -s /bin/bash "$username"
  log_message "User $username created with personal group $username."

  # Set permissions for the home directory
  chmod 700 /home/"$username"
  chown "$username":"$username" /home/"$username"

  # Generate a random password for the user
  password=$(generate_password)
  echo "$username:$password" | chpasswd

  # Add the user to the specified groups
  if [ -n "$groups" ]; then
    IFS=',' read -ra GROUPS <<< "$groups"
    for group in "${GROUPS[@]}"; do
      group=$(echo "$group" | xargs) # Trim whitespace
      # Check if the group exists, create if it doesn't
      if ! getent group "$group" &>/dev/null; then
        groupadd "$group"
        log_message "Group $group created."
      fi
      usermod -aG "$group" "$username"
      log_message "User $username added to group $group."
    end
  fi

  # Save the password securely
  echo "$username,$password" >> $PASSWORD_FILE
  log_message "Password for user $username stored securely."
done < "$INPUT_FILE"

log_message "User and group creation process completed."

# Set the correct permissions for the log file
chmod 644 $LOG_FILE

echo "User creation process completed. Check $LOG_FILE for details."
