# Unity Intercom Server, public as intercom.qo.ax (docs/unity-intercom.md).
# Its Pro encryption closes the TCP port, so clients need UDP alone; with
# "Leave TCP Port Open" ticked this would have to be tcp_udp. On both WANs so
# it still answers while the gateway has failed over to WAN2 and the record
# has followed.
resource "unifi_port_forward" "unity_intercom" {
  name     = "Unity Intercom"
  protocol = "udp"

  wan = {
    interface  = "both"
    ip_address = "any"
    port       = "20101"
  }

  forward = {
    ip   = unifi_client.mac4o_mini.fixed_ip
    port = "20101"
  }
}

# os-tues, the operating systems class's machine, as <student>@vm.os.tues.qo.ax
# (docs/os-tues.md). On both WANs, as the intercom, so SSH still answers while
# the gateway has failed over to WAN2 and the record has followed.
resource "unifi_port_forward" "os_tues_ssh" {
  name     = "os-tues SSH"
  protocol = "tcp"

  wan = {
    interface  = "both"
    ip_address = "any"
    port       = "22"
  }

  forward = {
    ip   = "192.168.4.31"
    port = "22"
  }
}

# qoax-broadcast-srt, Qoax's SRT relay, public as srt.qo.ax
# (docs/qoax-broadcast.md in qoax-community/qoax-infrastructure). Qoax sets
# the VM's address in that repository, so a move there must change forward.ip
# here too. SRT uses UDP alone. The forward is on both WANs, as the
# intercom's is. After a failover to WAN2 the record follows, and encoders
# still reach the relay. No source limit, because encoders publish from
# mobile networks and venues whose addresses nobody knows in advance.
resource "unifi_port_forward" "broadcast_srt" {
  name     = "qoax-broadcast SRT"
  protocol = "udp"

  wan = {
    interface  = "both"
    ip_address = "any"
    port       = "8890"
  }

  forward = {
    ip   = "192.168.12.23"
    port = "8890"
  }
}
