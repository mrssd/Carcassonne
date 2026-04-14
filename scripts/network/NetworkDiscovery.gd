class_name NetworkDiscovery
extends RefCounted

const DISCOVERY_PORT: int = 7001
const DISCOVERY_MESSAGE: String = "CARCASSONNE_SERVER"
const BROADCAST_INTERVAL: float = 1.0

var sock: PacketPeerUDP
var server_name: String = ""
var server_port: int = 7000

func start_server_broadcast(name: String, port: int) -> Error:
	"""Server broadcasts its availability"""
	server_name = name
	server_port = port
	sock = PacketPeerUDP.new()
	sock.set_broadcast_enabled(true)
	var err = sock.bind(DISCOVERY_PORT)
	return err

func start_client_discovery() -> Error:
	"""Client listens for server broadcasts"""
	sock = PacketPeerUDP.new()
	var err = sock.bind(DISCOVERY_PORT)
	return err

func broadcast_server(delta: float) -> void:
	"""Call this in _process() on the server"""
	if sock == null:
		return
	
	var message = "%s|%s|%d" % [DISCOVERY_MESSAGE, server_name, server_port]
	sock.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	sock.put_packet(message.to_utf8_buffer())

func get_available_servers() -> Array[Dictionary]:
	"""Call this in _process() on the client - returns discovered servers"""
	var servers: Array[Dictionary] = []
	
	if sock == null:
		return servers
	
	while sock.get_available_packet_count() > 0:
		var packet = sock.get_packet()
		var message = packet.get_string_from_utf8()
		
		var parts = message.split("|")
		if parts.size() == 3 and parts[0] == DISCOVERY_MESSAGE:
			var server_ip = sock.get_packet_ip()
			servers.append({
				"name": parts[1],
				"ip": server_ip,
				"port": int(parts[2])
			})
	
	return servers

func close() -> void:
	if sock != null:
		sock.close()
