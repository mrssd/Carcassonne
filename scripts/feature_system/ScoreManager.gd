class_name ScoreManager extends Node

@onready var turn_system = $"../TurnSystem"

#Signal for updated score
signal score_updated(player_index : int, new_score : int)

#Array to store player scores
var scores : Array[int] = []

func _ready() -> void:
    pass

func init_scores(player_count: int) -> void:
    scores.resize(player_count)
    scores.fill(0)

#Adds score to player
func add_score(player_index : int, points_added : int) -> void:
    # ensure valid index
    if player_index < 0:
        return

    scores[player_index] += points_added
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

