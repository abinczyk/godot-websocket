extends Node2D

onready var chat = get_node("CanvasLayer/Chat")
onready var dialog = get_node("CanvasLayer/Dialog")
var ws = WebSocketClient.new()
const PORT: int = 9080
var _server: WebSocketServer
var counter: int = 0

const PlayerChild = preload("res://src/scenes/Player.tscn")

func _ready():
	if Global.get_isHost() == true:
		self.StartServer()
	
	self.connection()

func connection():
	ws.connect("connection_established", self, "_connection_established")
	ws.connect("connection_closed", self, "_connection_closed")
	ws.connect("connection_error", self, "_connection_error")
	ws.connect("server_close_request", self, "_client_close_request")
	ws.connect("data_received", self, "_client_received")
	
	ws.connect("peer_packet", self, "_client_received")
	ws.connect("peer_connected", self, "_peer_connected")
	ws.connect("connection_succeeded", self, "_client_connected", ["multiplayer_protocol"])
	ws.connect("connection_failed", self, "_client_disconnected")
	
	var url = "ws://%s" % Global.get_serve_ip() 

	ws.connect_to_url(url)
	
	chat.append_text("[Game] connection to server %s" %url)
	chat.append_text("[Game] this could take a few seconds...")

func _peer_connected(id):
	chat.append_text("[Game] O player mit der  Id %s try to join" % id)

func _client_connected(protocol):
	chat.append_text("[Game] joined! - %s" %protocol)

func _client_disconnected(clean=true):
	chat.append_text("[Game] player leaved - %s" %clean)
	
func _connection_established(protocol):
	chat.append_text("[Game] connection established successfully! - %s" %protocol)	
	var data = {
		"type": 'OnPlayerAuth',
		"data": {
			"username": Global.get_username(),
			"pwd": Global.get_password(),
		}
	}
	ws.get_peer(1).put_var(data)
	
#	print(data)
#	var buf = JSON.print(data).to_utf8()
#	print(buf)
#	ws.get_peer(1).put_packet(buf)
	
func _connection_closed():
	chat.append_text("[Game] connection to server closed ")	

func _connection_error():
	chat.append_text("[Game] no connection to server")
func _client_close_request(code, reason):
	chat.append_text("connection closed: %d, por: %s" % [code, reason])
	
func _client_received():
	print ("RECEIVED")
	var packet = ws.get_peer(1).get_packet()

	var resultJSON = JSON.parse(packet.get_string_from_utf8())
	
	print(resultJSON.result)
	
	if resultJSON.result.type == 'message':
		return chat.append_text(resultJSON.result.message, resultJSON.result.color)
	elif resultJSON.result.type == 'showPlayerDialog':
		dialog._hide_dialog()
		
		dialog.dialogid = resultJSON.result.dialogid
		dialog.style = resultJSON.result.style
		
		dialog.button1.text = resultJSON.result.button1
		dialog.button2.text = resultJSON.result.button2
		
		dialog._set_caption(resultJSON.result.caption)
		dialog._set_info(resultJSON.result.info)
		
		dialog._show_dialog()
	elif resultJSON.result.type == 'spawnPlayer':
		
		var client = PlayerChild.instance()
		client.peerActive = resultJSON.result.active
		client.peerid = resultJSON.result.id
		client.skinID = resultJSON.result.skin
		client.position = Vector2(resultJSON.result.position.x, resultJSON.result.position.y)
		client.set_name("Player_%d" % client.peerid)
		client.connect("updatePlayer", self, "_on_Player_updatePlayer")
		$SpawnPlayer.add_child(client)
	
	elif resultJSON.result.type == 'updatePost':		
		var nameClient = "Player_%d" % resultJSON.result.id
		
		for client in get_node("SpawnPlayer").get_children():
			if client.get_name() == nameClient:
				client.position = Vector2(resultJSON.result.position.x, resultJSON.result.position.y)
				client.client_play(resultJSON.result.animation, resultJSON.result.flip)
	elif resultJSON.result.type == 'removePlayer':
		var nameClient = "Player_%d" % resultJSON.result.id
		
		for client in get_node("SpawnPlayer").get_children():
			if client.get_name() == nameClient:
				client.queue_free()
	pass
	
func _process(delta):
	if ws.get_connection_status() == ws.CONNECTION_CONNECTING || ws.get_connection_status() == ws.CONNECTION_CONNECTED:
		ws.poll()
	if Global.get_isHost() == true:
		PollServer(delta)
	pass

func _on_Chat_seedMessage(message):
	if ws.get_peer(1).is_connected_to_host():
		ws.get_peer(1).put_var({
			"type": 'OnPlayerText',
			"data": {
				"text": message
			}
		})
	pass


func _on_Player_updatePlayer(position, current_animation, flip):
	if ws.get_peer(1).is_connected_to_host():
		ws.get_peer(1).put_var({
			"type": 'onPlayerUpdate',
			"data": {
				"position": position,
				"animation": current_animation,
				"flip": flip
			}
		})
	pass


func _on_Dialog_dialogResponse(dialogid, response, listitem, inputtext):
	if ws.get_peer(1).is_connected_to_host():
		ws.get_peer(1).put_var({
			"type": 'onDialogResponse',
			"data": {
				"dialogid": dialogid,
				"response": response,
				"listitem": listitem,
				"inputtext": inputtext,
			}
		})
	pass

func StartServer() -> void:
	_server = WebSocketServer.new()
	_server.connect("client_connected", self, "OnClientConnected")
	_server.connect("data_received", self, "OnDataReceived")
	
	var err: = _server.listen(PORT)
	print("Connecting ...")
	if err != OK:
		print("Could not establish server connection")
		set_process(false)
		return
	print("Listening on port %d ..." % PORT)
	
func PollServer(_delta) -> void:
	_server.poll()


func OnClientConnected(id, proto) -> void:
	print("User ID: %d has entered." % id)
	var data = 1234
	_server.set_target_peer(0)
	_server.put_var(data)

func _on_Timer_timeout():
	print("[%d] waiting for new packets." % counter)
	counter += 1
	
func OnDataReceived(id: int) -> void:
	var packet = _server.get_peer(id).get_var()
	_server.put_var(packet)
	
	print("New data received from User [%d]: %s" % [id, packet])
	
	var type = packet["type"]
	var data = packet["data"]
	print(type)
	print(data)
	
	match type:
		"OnPlayerAuth":
			print("Username: " + data["username"])
			print("Password: " + data["pwd"])
		"OnPlayerText":
			chat.append_text(data["text"])
			print(data["text"])
			_server.set_target_peer(0)
			_server.put_var(123456)
			_server.put_packet(JSON.print({
				"type" : 'message',
				"message" : data["text"],
				"color" : '"ffffff'
				}).to_utf8()
			)
		
	

