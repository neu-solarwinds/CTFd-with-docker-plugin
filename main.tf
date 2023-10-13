provider "google" {
  region = "us-central1"
}

resource "google_project" "project" {
  name       = "ctfd-project"
  org_id     = 0
  project_id = "ctfd-${random_string.project_suffix.result}"
}

resource "random_string" "project_suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "google_project_service" "service" {
  project = google_project.project.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "service2" {
  project = google_project.project.project_id
  service = "logging.googleapis.com"

  disable_on_destroy = false
}

resource "google_compute_address" "static_address" {
  name = "ctfd-static-ip"
}

resource "google_compute_instance" "vm" {
  name         = "ctfd-vm"
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
      nat_ip = google_compute_address.static_address.address
    }
  }

  metadata = {
    startup-script = <<-EOF
      sudo apt-get update
      sudo apt-get install -y docker.io git
      git clone https://github.com/neu-solarwinds/CTFd-with-docker-plugin
      cd CTFd-with-docker-plugin
      docker-compose up -d
    EOF
  }
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_logging_project_sink" "logging_sink" {
  name        = "ctfd-logs"
  destination = "logging.googleapis.com"

  filter = "resource.type=gce_instance AND logName:docker"
}

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
