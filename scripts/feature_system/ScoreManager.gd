class_name ScoreManager extends Node

@onready var turn_system = $"../TurnSystem"

#Signal for updated score
signal score_updated(player_index : int, new_score : int)

#Array to store player scores
var scores : Array[int] = []

func _ready() -> void:
    #Initialize score based on player count from TurnSystem
    if turn_system:
        scores.resize(turn_system.players.size())
        scores.fill(0)

#Adds score to player
func add_score(player_index : int, points_added : int) -> void:
    # ensure valid index
    if player_index < 0:
        return

    scores[player_index] += points_added
    #debug temp
    print("ScoreManager: add_score called for player", player_index, "new score:", scores[player_index])
    score_updated.emit(player_index, scores[player_index])

#Gets score of player
func get_score(player_index : int) -> int :
    if player_index >= 0 and player_index < scores.size():
        return scores[player_index]
    return 0

#Get formatted score for UI
func get_all_scores_text() -> String:
    var result : String = ""
    for i in range(scores.size()):
        if turn_system:
            result += "%s: %d\n" % [turn_system.players[i], scores[i]]
    return result

