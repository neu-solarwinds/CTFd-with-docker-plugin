import os
import sys
import shutil
import random
import subprocess
import mysql.connector

# Define MySQL connection parameters
DB_HOST = 'localhost'  # or your MySQL server IP
DB_USER = 'ctfd'  # your MySQL username
DB_PASSWORD = 'ctfd'  # your MySQL password
DB_DATABASE = 'ctfd'  # your MySQL database name

NUMOFTEAMS = 2
CONTAINERS_TABLE = "container_challenge_model"
FLAG_TABLE = "flags"

def get_db_connection():
    """Get a MySQL database connection."""
    return mysql.connector.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_DATABASE
    )

def find_challenge_dirs(base_path):
    """Find all directories with a Dockerfile and flag.txt under the given path."""
    challenge_dirs = []

    for root, _, files in os.walk(base_path):
        if 'Dockerfile' in files and 'flag.txt' in files:
            challenge_dirs.append(root)

    return challenge_dirs


def modify_flag_content(directory):
    """Modify the flag content by adding 8 random characters."""
    chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    flag_file = os.path.join(directory, 'flag.txt')
    
    with open(flag_file, 'r') as f:
        flag_content = f.read().strip()
    
    random_str = ''.join(random.choice(chars) for i in range(8))
    new_flag_content = flag_content[:-1] + '_' + random_str + '}'
    
    with open(flag_file, 'w') as f:
        f.write(new_flag_content)
    
    return new_flag_content

def process_team_directories(target_dir, container_mapping):
    """Process each TEAM# directory and its challenges."""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        for i in range(1, NUMOFTEAMS + 1):
            team_dir = os.path.join(target_dir, f"TEAM{i}")
            
            for challenge_dir_name in os.listdir(team_dir):
                challenge_dir_path = os.path.join(team_dir, challenge_dir_name)
                
                # Check if challenge directory name is in the container mapping
                if challenge_dir_name not in container_mapping:
                    print(f"Challenge {challenge_dir_name} was not found in container mapping!")
                    print("EXITING PROGRAM")
                    sys.exit(1)

                container_id = container_mapping[challenge_dir_name]
                
                # Check if there's already a row with the same container ID and TEAMID
                cursor.execute(f"SELECT * FROM {FLAG_TABLE} WHERE challenge_id=%s AND data=%s", (container_id, f"TEAMID={i}"))
                existing_row = cursor.fetchone()
                
                if existing_row:
                    print(f"Row already exists for container ID {container_id} and TEAMID={i}: {existing_row}")
                    print("EXITING PROGRAM")
                    sys.exit(1)
                
                # Modify the flag content
                new_flag_content = modify_flag_content(challenge_dir_path)
                
                # Build the Docker image
                tag = f"{challenge_dir_name}:TEAM{i}"
                subprocess.run(['docker', 'build', '-t', tag, challenge_dir_path])
                    
  		# Insert into FLAG_TABLE, without specifying the ID
                insert_query = f"INSERT INTO {FLAG_TABLE} (challenge_id, type, content, data) VALUES (%s, %s, %s, %s)"
                cursor.execute(insert_query, (container_id, "static", new_flag_content, f"TEAMID={i}"))
                conn.commit()

    finally:
        conn.close()



def deploy_for_teams(challenge_dirs, target_dir):
    """Deploy challenges to team directories."""
    for i in range(1, NUMOFTEAMS + 1):
        team_dir = os.path.join(target_dir, f"TEAM{i}")
        
        # Create team directory if it doesn't exist
        if not os.path.exists(team_dir):
            os.makedirs(team_dir)

        for challenge_dir in challenge_dirs:
            challenge_name = os.path.basename(challenge_dir).lower()
            target_challenge_dir = os.path.join(team_dir, challenge_name)

            if os.path.exists(target_challenge_dir):
                print(f"{target_challenge_dir} already exists. Overwriting...")
                shutil.rmtree(target_challenge_dir)

            shutil.copytree(challenge_dir, target_challenge_dir)
            print(f"Copied {challenge_name} to {target_challenge_dir}")

def get_container_mapping():
    """Retrieve container name to ID mapping from the database."""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(f"SELECT * FROM {CONTAINERS_TABLE}")
    rows = cursor.fetchall()

    container_map = {}
    for row in rows:
        container_name = row[1].split(":")[0]  # Get the name without ':latest'
        container_map[container_name] = row[0]

    conn.close()
    return container_map

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 script_name.py <source_path> <target_path>")
        sys.exit(1)

    source_dir = sys.argv[1]
    target_dir = sys.argv[2]

    if not os.path.isdir(source_dir):
        print(f"The source path {source_dir} is not a valid directory.")
        sys.exit(1)

    if not os.path.isdir(target_dir):
        print(f"The target path {target_dir} is not a valid directory.")
        sys.exit(1)

    challenge_dirs = find_challenge_dirs(source_dir)
    deploy_for_teams(challenge_dirs, target_dir)
    container_mapping = get_container_mapping()
    print(container_mapping)
    process_team_directories(target_dir, container_mapping)
