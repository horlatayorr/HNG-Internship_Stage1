#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if the input file is provided and exists
if [ $# -ne 1 ]; then
    echo "Usage: $0 <usernames_file>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "File $1 not found!"
    exit 1
fi

# Log file and secure password storage
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure the existence of the log and password files and set appropriate permissions
touch $LOG_FILE
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Read the file line by line
while IFS= read -r line
do
    # Extract username and groups, ignoring whitespace
    IFS=';' read -ra ADDR <<< "$line"
    username="${ADDR[0]}"
    groups="${ADDR[1]// /}"

    # Create a personal group for the user
    if ! grep -q "^$username:" /etc/group; then
        groupadd "$username"
        echo "Group $username created." >> $LOG_FILE
    fi

    # Create the user with the personal group
    if ! id "$username" &>/dev/null; then
        useradd -m -g "$username" -s /bin/bash "$username"
        echo "User $username with group $username created." >> $LOG_FILE

        # Generate a random password
        password=$(openssl rand -base64 12)
        echo "$username:$password" | chpasswd
        echo "$username,$password" >> $PASSWORD_FILE
        echo "Password for $username generated and stored securely." >> $LOG_FILE
    else
        echo "User $username already exists. Skipping." >> $LOG_FILE
    fi

    # Assign additional groups, if any
    if [ ! -z "$groups" ]; then
        IFS=',' read -ra GROUPS <<< "$groups"
        for group in "${GROUPS[@]}"; do
            if ! grep -q "^$group:" /etc/group; then
                groupadd "$group"
                echo "Group $group created." >> $LOG_FILE
            fi
            usermod -aG "$group" "$username"
            echo "User $username added to group $group." >> $LOG_FILE
        done
    fi
done < "$1"

echo "User creation process completed."