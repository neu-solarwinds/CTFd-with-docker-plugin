
provider "google" {
  region = "us-central1"
}

resource "google_project" "new_project" {
  name       = "ctfd-project"
  project_id = "ctfd-${random_string.project_suffix.result}"
  org_id     = "0"
}

resource "random_string" "project_suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "google_project_service" "compute_api" {
  project = google_project.new_project.project_id
  service = "compute.googleapis.com"
}

resource "google_project_service" "service_networking_api" {
  project = google_project.new_project.project_id
  service = "servicenetworking.googleapis.com"
}

resource "google_compute_instance" "vm1" {
  project      = google_project.new_project.project_id
  name         = "vm1"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = <<-SCRIPT
    apt-get update && apt-get install -y git docker.io docker-compose
    git clone https://github.com/neu-solarwinds/CTFd-with-docker-plugin
    echo 'location ~ ^/admin { deny all; }' >> CTFd-with-docker-plugin/conf/nginx/http.conf
    cd CTFd-with-docker-plugin && docker-compose up -d
  SCRIPT

  depends_on = [
    google_project_service.compute_api,
    google_project_service.service_networking_api
  ]
}

resource "google_compute_instance" "vm2" {
  project      = google_project.new_project.project_id
  name         = "vm2"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = <<-SCRIPT
    apt-get update && apt-get install -y docker.io
    systemctl enable docker && systemctl start docker
  SCRIPT

  depends_on = [
    google_project_service.compute_api,
    google_project_service.service_networking_api
  ]
}

resource "google_compute_firewall" "allow-8000" {
  project = google_project.new_project.project_id
  name    = "allow-8000"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-8080" {
  project = google_project.new_project.project_id
  name    = "allow-8080"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
}


# Existing configuration ...

resource "google_compute_address" "vm1_static_ip" {
  project = google_project.new_project.project_id
  name    = "vm1-static-ip"
  region  = "us-central1"
}

resource "google_compute_address" "vm2_static_ip" {
  project = google_project.new_project.project_id
  name    = "vm2-static-ip"
  region  = "us-central1"
}

# Update VM1 definition
resource "google_compute_instance" "vm1" {
  # ... existing VM1 configuration ...

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.vm1_static_ip.address
    }
  }

  # ... rest of VM1 configuration ...
}

# Update VM2 definition
resource "google_compute_instance" "vm2" {
  # ... existing VM2 configuration ...

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.vm2_static_ip.address
    }
  }

  # ... rest of VM2 configuration ...
}

# ... rest of the configuration ...
