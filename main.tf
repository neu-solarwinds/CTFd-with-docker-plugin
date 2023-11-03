provider "google" {
  region = "us-central1"
}

data "google_project" "project" {
  project_id = "carbide-datum-402521"
}

resource "google_project_service" "service" {
  project = data.google_project.project.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "service2" {
  project = data.google_project.project.project_id
  service = "logging.googleapis.com"

  disable_on_destroy = false
}

resource "google_compute_address" "static_address" {
  name = "ctfd-static-ip"
}

resource "google_compute_instance" "vm" {
  name         = "ctfd-vm"
  machine_type = "e2-standard-2"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.static_address.address
    }
  }
  
  service_account {
    scopes = ["logging-write"]
  }
  metadata = {
    google-logging-enabled    = "true"
    startup-script = <<-EOF
      #!/bin/bash
      echo 'starting startup script'
      sudo mkdir /ctfd
      sudo apt-get update
      sudo apt-get install -y docker.io git
      # Docker is already installed? just need to run the daemon
      sudo systemctl enable docker
      sudo systemctl start docker
      sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
      docker-compose --version
      echo 'Set the gcplogs logging driver for Docker'
      sudo echo '{ "log-driver": "gcplogs", "log-opts": { "gcp-meta-name": "my-instance-name" } }' | sudo tee /etc/docker/daemon.json
      sudo systemctl restart docker
      git clone https://github.com/neu-solarwinds/CTFd-with-docker-plugin
      cd CTFd-with-docker-plugin
      docker-compose up -d
      cd ..
      echo 'finished startup script'
      echo 'start configure ctfd'
      git clone https://github.com/neu-solarwinds/CTF-goat.git  
      echo 'finish configure ctfd'
    EOF
  }
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# todo need 
# Configure the Docker daemon to use the gcplogs logging driver by setting the log-driver and log-opts keys in the daemon.json file. For example, you can set the log-driver key to gcplogs and the gcp-meta-name option to a unique name for your instance. Here is an example daemon.json file:
# {
#   "log-driver": "gcplogs",
#   "log-opts": {
#     "gcp-meta-name": "my-instance-name"
#   }
# }
# resource "google_logging_project_sink" "logging_sink" {
#   name        = "ctfd-logs"
#   destination = "logging.googleapis.com"

#   filter = "resource.type=gce_instance AND logName:docker"
# }

resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Notification"
  type         = "email"
  labels = {
    email_address = "Sneider.b@northeastern.edu"
  }
}

resource "google_monitoring_alert_policy" "alert_policy" {
  display_name = "CTFd Docker Down Alert"

  conditions {
    display_name = "CTFd Docker Down"
    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/disk/write_bytes_count\" AND resource.type=\"gce_instance\" AND resource.label.\"instance_id\"=\"ctfd-vm\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "60s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  combiner = "OR"
  enabled  = true

  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]
}
