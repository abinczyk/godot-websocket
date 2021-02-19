extends Node

var username = 'Visitante'
var serve_ip = 'iobroker:1880'
var password = 'mypwd'
var isHost = false

func get_username() -> String:
	return username
func get_password() -> String:
	return password

func set_username(name: String) -> void:
	username = name

func get_serve_ip() -> String:
	return serve_ip

func set_serve_ip(ip: String) -> void:
	serve_ip = ip

func get_isHost() -> bool:
	return isHost

func set_isHost(chk: bool) -> void:
	isHost = chk

