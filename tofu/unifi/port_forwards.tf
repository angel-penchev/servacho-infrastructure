resource "unifi_port_forward" "minecraft_server" {
  name     = "Minecraft Server"
  enabled  = false
  protocol = "tcp_udp"

  wan = {
    interface  = "both"
    ip_address = "any"
    port       = "25565"
  }

  forward = {
    ip   = "192.168.4.20"
    port = "25565"
  }

  lifecycle {
    ignore_changes = [destination_ips]
  }
}

resource "unifi_port_forward" "nginx_proxy" {
  name     = "Personal Server Nginx Proxy Manager"
  enabled  = true
  protocol = "tcp_udp"

  wan = {
    interface  = "wan"
    ip_address = "any"
    port       = "80,443"
  }

  forward = {
    ip   = "192.168.5.102"
    port = "80,443"
  }

  lifecycle {
    ignore_changes = [destination_ips]
  }
}

resource "unifi_port_forward" "fmicodes_db" {
  name     = "fmicodes db"
  enabled  = true
  protocol = "tcp_udp"

  wan = {
    interface  = "wan"
    ip_address = "any"
    port       = "5432"
  }

  forward = {
    ip   = "192.168.5.200"
    port = "5432"
  }

  lifecycle {
    ignore_changes = [destination_ips]
  }
}

resource "unifi_port_forward" "fmicodes_ssh" {
  name     = "fmicodes ssh"
  enabled  = true
  protocol = "tcp_udp"

  wan = {
    interface  = "wan"
    ip_address = "any"
    port       = "2242"
  }

  forward = {
    ip   = "192.168.5.200"
    port = "22"
  }

  lifecycle {
    ignore_changes = [destination_ips]
  }
}

resource "unifi_port_forward" "fmicodes_ssh_worker" {
  name     = "fmicodes ssh (worker)"
  enabled  = true
  protocol = "tcp_udp"

  wan = {
    interface  = "wan"
    ip_address = "any"
    port       = "2243"
  }

  forward = {
    ip   = "192.168.5.201"
    port = "22"
  }

  lifecycle {
    ignore_changes = [destination_ips]
  }
}

resource "unifi_port_forward" "fmicodes_intercom" {
  name     = "fmicodes intercom bullshit"
  enabled  = false
  protocol = "udp"

  wan = {
    interface  = "wan"
    ip_address = "any"
    port       = "10000-11433,11435-25564,25566-51819,51821-60000"
  }

  forward = {
    ip   = "192.168.5.215"
    port = "10000-11433,11435-25564,25566-51819,51821-60000"
  }

  lifecycle {
    ignore_changes = [destination_ips]
  }
}
