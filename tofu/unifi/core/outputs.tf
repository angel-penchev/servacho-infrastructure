output "network_default_id" { value = unifi_network.default.id }
output "network_main_id" { value = unifi_network.main.id }
output "network_guest_id" { value = unifi_network.guest.id }
output "network_public_servers_id" { value = unifi_network.public_servers.id }
output "network_private_servers_id" { value = unifi_network.private_servers.id }
output "network_iot_id" { value = unifi_network.iot.id }
output "network_qoax_community_vps_id" { value = unifi_network.qoax_community_vps.id }
output "network_qoax_community_broadcast_vps_id" { value = unifi_network.qoax_community_broadcast_vps.id }
output "network_fmicodes_vps_id" { value = unifi_network.fmicodes_vps.id }

output "port_profile_main_id" { value = unifi_port_profile.main.id }
output "port_profile_iot_id" { value = unifi_port_profile.iot.id }
output "port_profile_public_servers_id" { value = unifi_port_profile.public_servers.id }
output "port_profile_private_servers_id" { value = unifi_port_profile.private_servers.id }

output "wan_vivacom_primary_id" { value = unifi_wan.vivacom_primary.id }
output "wan_vivacom_secondary_id" { value = unifi_wan.vivacom_secondary.id }
output "port_profile_unifi_devices_id" { value = unifi_port_profile.unifi_devices.id }
