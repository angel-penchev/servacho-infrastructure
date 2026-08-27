resource "unifi_client" "michelangelo" {
  mac            = "34:5a:60:7a:62:05"
  name           = "MICHELANGELO"
  fixed_ip       = "192.168.2.178"
  network_id     = unifi_network.main.id
  allow_existing = true
}

resource "unifi_client" "jetkvm" {
  mac            = "30:52:53:08:45:16"
  name           = "jetkvm-9e62320c932c192c"
  fixed_ip       = "192.168.5.21"
  network_id     = unifi_network.private_servers.id
  allow_existing = true
}

resource "unifi_client" "sami_dev_machine" {
  mac            = "bc:24:11:b0:83:56"
  name           = "SAMI-DEV-MACHINE"
  fixed_ip       = "192.168.4.32"
  network_id     = unifi_network.public_servers.id
  allow_existing = true
}

resource "unifi_client" "rpi_petacho" {
  mac            = "2c:cf:67:33:a5:49"
  name           = "rpi-petacho"
  fixed_ip       = "192.168.4.20"
  network_id     = unifi_network.public_servers.id
  allow_existing = true
}

resource "unifi_client" "networkboot_server" {
  mac            = "bc:24:11:9f:f8:56"
  name           = "networkboot-server"
  fixed_ip       = "192.168.5.31"
  network_id     = unifi_network.private_servers.id
  allow_existing = true
}

resource "unifi_client" "tsb_mint" {
  mac            = "00:00:c4:54:44:f9"
  name           = "tsb-mint"
  fixed_ip       = "192.168.4.15"
  network_id     = unifi_network.public_servers.id
  allow_existing = true
}

resource "unifi_client" "djam_11" {
  mac            = "00:e0:5c:36:1b:41"
  name           = "DJAM-11"
  fixed_ip       = "192.168.4.10"
  network_id     = unifi_network.public_servers.id
  allow_existing = true
}

resource "unifi_client" "nixos" {
  mac            = "bc:24:11:75:a0:71"
  name           = "nixos"
  fixed_ip       = "192.168.4.228"
  network_id     = unifi_network.public_servers.id
  allow_existing = true
}

resource "unifi_client" "minecraft_fabric_server" {
  mac            = "bc:24:11:90:56:95"
  name           = "minecraft-fabric-server"
  fixed_ip       = "192.168.4.25"
  network_id     = unifi_network.public_servers.id
  allow_existing = true
}
