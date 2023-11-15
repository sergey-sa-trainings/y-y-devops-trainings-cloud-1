terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "./sa-terraform-hw2-key.json"
  folder_id                = local.folder_id
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "foo" {}

resource "yandex_vpc_subnet" "foo" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.foo.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

resource "yandex_container_registry" "registry-hw2" {
  name = "registry-hw2"
}

output "container_registry_id" {
  value = yandex_container_registry.registry-hw2.id
}

locals {
  folder_id = "b1gi3jo0sam0o77lva2p"
  service-accounts = toset([
    "catgpt-ig", "catgpt-it"
  ])
  catgpt-ig-roles = toset([
    "vpc.admin",
    "vpc.user",
    "iam.serviceAccounts.user",
    "load-balancer.admin",
    "compute.editor"
  ])
  catgpt-it-roles = toset([
    "container-registry.images.puller",
    "monitoring.editor",
  ])
}
resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = "${local.folder_id}-${each.key}"
}
resource "yandex_resourcemanager_folder_iam_member" "catgpt-ig-roles" {
  for_each  = local.catgpt-ig-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["catgpt-ig"].id}"
  role      = each.key
}
resource "yandex_resourcemanager_folder_iam_member" "catgpt-it-roles" {
  for_each  = local.catgpt-it-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["catgpt-it"].id}"
  role      = each.key
}

data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}

resource "yandex_compute_instance_group" "catgpt-2" {
  service_account_id = yandex_iam_service_account.service-accounts["catgpt-ig"].id
  folder_id          = local.folder_id
  instance_template {
    service_account_id = yandex_iam_service_account.service-accounts["catgpt-it"].id
    platform_id        = "standard-v2"
    resources {
      cores         = 2
      memory        = 1
      core_fraction = 5
    }
    metadata = {
      docker-compose = file("${path.module}/docker-compose.yaml")
      ssh-keys       = "ubuntu:${file("~/.ssh/y-devops-training.pub")}"
      user-data = "${file("${path.module}/cloud-config.yaml")}"
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = data.yandex_compute_image.coi.id
        type     = "network-hdd"
        size     = "30"
      }
    }
    network_interface {
      network_id = yandex_vpc_network.foo.id
      subnet_ids = [yandex_vpc_subnet.foo.id]
      nat        = true
    }
    network_settings {
      type = "STANDARD"
    }
    scheduling_policy {
      preemptible = true
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 1
    max_creating    = 1
    max_expansion   = 1
    max_deleting    = 1
  }

  load_balancer {
    target_group_name = "catgpt-2"
  }
}

resource "yandex_lb_network_load_balancer" "lb-hw2" {
  name = "lb-hw2"

  listener {
    name = "my-listener"
    port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.catgpt-2.load_balancer.0.target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}
