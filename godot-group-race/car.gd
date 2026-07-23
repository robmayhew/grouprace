class_name car

extends CharacterBody2D


func fetch_body() -> CharacterBody2D:
	push_error("Car has no body")
	return null
