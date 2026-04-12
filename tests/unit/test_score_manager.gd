extends GutTest

var score_manager: ScoreManager

func before_each():
	score_manager = ScoreManager.new()
	score_manager.init_scores(2)

func after_each():
	score_manager.free()

func test_initial_scores_are_zero():
	assert_eq(score_manager.get_score(0), 0)
	assert_eq(score_manager.get_score(1), 0)

func test_add_score_accumulates():
	score_manager.add_score(0, 5)
	score_manager.add_score(0, 3)
	assert_eq(score_manager.get_score(0), 8)

func test_add_score_does_not_affect_other_player():
	score_manager.add_score(0, 10)
	assert_eq(score_manager.get_score(1), 0)

func test_players_score_independently():
	score_manager.add_score(0, 4)
	score_manager.add_score(1, 7)
	assert_eq(score_manager.get_score(0), 4)
	assert_eq(score_manager.get_score(1), 7)

func test_invalid_negative_index_is_ignored():
	score_manager.add_score(-1, 100)
	assert_eq(score_manager.get_score(0), 0)
	assert_eq(score_manager.get_score(1), 0)

func test_invalid_out_of_bounds_index_is_ignored():
	score_manager.add_score(5, 100)
	assert_eq(score_manager.get_score(0), 0)
	assert_eq(score_manager.get_score(1), 0)

func test_get_score_invalid_index_returns_zero():
	assert_eq(score_manager.get_score(-1), 0)
	assert_eq(score_manager.get_score(99), 0)
