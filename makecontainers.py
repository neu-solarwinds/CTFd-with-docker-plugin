import os
import sys
import subprocess

def find_dockerfiles(base_path):
    """Find all directories with a Dockerfile under the given path."""
    docker_dirs = []

    for root, _, files in os.walk(base_path):
        if 'Dockerfile' in files:
            docker_dirs.append(root)

    return docker_dirs

def build_docker_images(docker_dirs):
    """Build docker images from the directories provided."""
    for d in docker_dirs:
        # Extract the name of the directory for the Docker container name
        print("Processing directory ---> ",d)
        container_name = os.path.basename(d)
        try:
            subprocess.run(['docker', 'build', '-t', f'{container_name.lower()}:latest', d], check=True)
            print(f"Successfully built {container_name}:latest")
        except subprocess.CalledProcessError:
            print(f"Failed to build Docker image for {container_name}")
            continue

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python3 makecontainers.py <path_to_scan>")
        sys.exit(1)

    base_path = sys.argv[1]

    if not os.path.isdir(base_path):
        print(f"The path {base_path} is not a valid directory.")
        sys.exit(1)

    docker_dirs = find_dockerfiles(base_path)
    print(docker_dirs)
    build_docker_images(docker_dirs)
