#!/bin/bash

# Define variables
CONFIG_FILE="/etc/mongod.conf"
KEYFILE_PATH="/var/lib/mongodb/keyfile.pem"
REPLICA_SET_NAME="rs-name"
SERVICE_NAME="mongod"
USERNAME="database-user"
PASSWORD="strong-password"
AUTH_DATABASE="admin"
PORT="27011"

echo "Generating keyFile..."
openssl rand -base64 741 > "$KEYFILE_PATH"
chmod 600 "$KEYFILE_PATH"
chown mongodb:mongodb "$KEYFILE_PATH"

# Stop the MongoDB service
echo "Stopping MongoDB service..."
systemctl stop "$SERVICE_NAME"

# Modify config file for replica set
echo "Configuring for replica set..."
sed -i '/^security:/a \  keyFile: '"$KEYFILE_PATH"'' "$CONFIG_FILE"
sed -i 's/^#replication:/replication:/' "$CONFIG_FILE"
sed -i '/^replication:/a \  replSetName: '"$REPLICA_SET_NAME"'' "$CONFIG_FILE"

# Restart MongoDB service
echo "Restarting MongoDB service..."
systemctl start "$SERVICE_NAME"

# Function to check whether the user can log in to MongoDB
check_mongo_login() {
    echo "Checking MongoDB login..."
    mongo --eval "db.runCommand({ ping: 1 })" -u "$USERNAME" -p "$PASSWORD" --authenticationDatabase "$AUTH_DATABASE" --port "$PORT"
}

# Loop to check MongoDB login every 10 seconds
while ! check_mongo_login; do
    echo "Failed to log in to MongoDB. Retrying in 10 seconds..."
    sleep 10
done

# Initialize replica set with existing data
echo "Initializing replica set..."
mongo --eval "rs.initiate({
  '_id': '$REPLICA_SET_NAME',
    'members': [
    { '_id': 0, 'host': '172.31.27.237:27011' }
  ]
})" -u "$USERNAME" -p "$PASSWORD" --authenticationDatabase "$AUTH_DATABASE" --port "$PORT"

# Wait for the MongoDB replica set to be initialized
sleep 5

# Check the replica set status
echo "Checking replica set status..."
mongo --eval "rs.status()" -u $USERNAME -p $PASSWORD --authenticationDatabase $AUTH_DATABASE --port $PORT

echo "Conversion to replica set complete!"