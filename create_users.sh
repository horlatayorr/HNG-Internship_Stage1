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
#Backing up created files
log_message "Backing up created files"
cp "$PASSWORD_FILE" "${PASSWORD_FILE}.bak"
cp "LOG_FILE" "${LOG_FILE}.bak"

# Function to generate random passwords
generate_password() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Read the input file line by line
while IFS=';' read -r username groups; do
  # Trim whitespace
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)

  #Parse the username and groups
  echo "$username"
  echo "$groups"

  # Check if the line is empty
  if [ -z "$username" ]; then
    log_message "Empty or malformed line skipped."
    continue
  fi

  # Check if the user already exists
  if id "$username" &>/dev/null; then
    log_message "User $username already exists."
  else
    # Create the user's personal group
    groupadd "$username"
    # Create the user with the personal group
    useradd -m -g "$username" -s /bin/bash "$username"
    if [ $? -eq 0 ]; then
      log_message "User $username created with home directory."
    else
      log_message "Failed to create user $username."
        continue
    fi

  # Set permissions for the home directory
  chmod 700 /home/"$username"
  chown "$username":"$username" /home/"$username"
  log_message "Home directory Permissions set for user $username."

  # Generate a random password for the user
  password=$(generate_password)
  echo "$username:$password" | chpasswd
  if [ $? -eq 0 ]; then
    log_message "Password for user $username set."
  else
    log_message "Failed to set password for user $username."
  fi
  # Save the password securely
  echo "$username,$password" >> $PASSWORD_FILE
  log_message "Password for user $username stored securely."

# Add the user to the specified groups
if [ -n "$groups" ]; then
    IFS=',' read -ra groups_ARRAY <<< "$groups"
    for groups in "${groups_ARRAY[@]}"; do
      # Check if the group exists, create if it doesn't
      if ! getent group "$groups" &>/dev/null; then
        groupadd "$groups"
        log_message "Group $groups created."
      fi
      #Add User to the groups
      usermod -aG "$groups" "$username"
      if [ $? -eq 0 ]; then
          log_message "User $username added to group $groups."
      else
          log_message "Failed to add user $username to group $groups."
        fi
    done
  fi

 
done < "$INPUT_FILE"
log_message "User and group creation process completed."

# Set the correct permissions for the log file
chmod 644 $LOG_FILE

echo "User creation process completed. Check $LOG_FILE for details."
