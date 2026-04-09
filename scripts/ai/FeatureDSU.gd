class_name FeatureDSU

var _parent: Dictionary = {}
var _rank: Dictionary = {}
var _tile_count: Dictionary = {}
var _open_ports: Dictionary = {}
var _shield_count: Dictionary = {}
var _meeple_counts: Dictionary = {}  # root -> {player_index: count}

var _undo_ops: Array = []
var _checkpoints: Array = []

# (x,y)|segment e.g. 3,5|city_nw
static func node_key(cell: Vector2i, seg: String) -> String:
	return "%d,%d|%s" % [cell.x, cell.y, seg]


func has_node(key: String) -> bool:
	return _parent.has(key)


#Create new isolated feature segment initial_ports = number of edges in the segment (all start open).
func make_node(key: String, initial_ports: int, shields: int) -> void:
	if _parent.has(key):
		return
	_parent[key] = key
	_rank[key] = 0
	_tile_count[key] = 1
	_open_ports[key] = initial_ports
	_shield_count[key] = shields
	_meeple_counts[key] = {}
	_undo_ops.append({"op": "make", "k": key})


#Find root without path compression
func find(key: String) -> String:
	var k = key
	while _parent[k] != k:
		k = _parent[k]
	return k


#Connects two feature segmenet when tile touch
func union(a: String, b: String) -> void:
	var ra = find(a)
	var rb = find(b)
	#Same root
	if ra == rb:
		var old_op = _open_ports[ra]
		_open_ports[ra] = maxi(0, old_op - 2)
		_undo_ops.append({"op": "close", "r": ra, "old_op": old_op})
		return
	#Union by rank
	if _rank[ra] < _rank[rb]:
		var tmp = ra; ra = rb; rb = tmp
	_undo_ops.append({
		"op": "union", "ra": ra, "rb": rb,
		"old_pb": _parent[rb],
		"old_rka": _rank[ra],
		"old_tc": _tile_count[ra],
		"old_op": _open_ports[ra],
		"old_sc": _shield_count[ra],
		"old_mc": _meeple_counts[ra].duplicate()
	})
	_parent[rb] = ra
	if _rank[ra] == _rank[rb]:
		_rank[ra] += 1
	_tile_count[ra] += _tile_count[rb]
	_open_ports[ra] = _open_ports[ra] + _open_ports[rb] - 2
	_shield_count[ra] += _shield_count[rb]
	var mc = _meeple_counts[ra].duplicate()
	for p in _meeple_counts[rb]:
		mc[p] = mc.get(p, 0) + _meeple_counts[rb][p]
	_meeple_counts[ra] = mc


func add_meeple(key: String, player: int) -> void:
	var r = find(key)
	var old = _meeple_counts[r].duplicate()
	_meeple_counts[r][player] = _meeple_counts[r].get(player, 0) + 1
	_undo_ops.append({"op": "meeple", "r": r, "old": old})


#Save a rollback point before a hypothetical tile placement
func push_checkpoint() -> void:
	_checkpoints.append(_undo_ops.size())


#Undo all DSU operations since the last push_checkpoint
func pop_checkpoint() -> void:
	var cp = _checkpoints.pop_back()
	while _undo_ops.size() > cp:
		var op = _undo_ops.pop_back()
		match op["op"]:
			"make":
				_parent.erase(op["k"])
				_rank.erase(op["k"])
				_tile_count.erase(op["k"])
				_open_ports.erase(op["k"])
				_shield_count.erase(op["k"])
				_meeple_counts.erase(op["k"])
			"union":
				_parent[op["rb"]] = op["old_pb"]
				_rank[op["ra"]] = op["old_rka"]
				_tile_count[op["ra"]] = op["old_tc"]
				_open_ports[op["ra"]] = op["old_op"]
				_shield_count[op["ra"]] = op["old_sc"]
				_meeple_counts[op["ra"]] = op["old_mc"]
			"close":
				_open_ports[op["r"]] = op["old_op"]
			"meeple":
				_meeple_counts[op["r"]] = op["old"]

#Getter functions

func get_tile_count(key: String) -> int:
	return _tile_count.get(find(key), 0)


func get_open_ports(key: String) -> int:
	return _open_ports.get(find(key), 0)


func get_shield_count(key: String) -> int:
	return _shield_count.get(find(key), 0)


func get_meeple_counts(key: String) -> Dictionary:
	return _meeple_counts.get(find(key), {})
