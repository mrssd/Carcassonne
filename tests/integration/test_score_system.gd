extends GutTest

var score_system: ScoreSystem
var score_manager: ScoreManager

func before_each():
	score_manager = ScoreManager.new()
	score_manager.init_scores(3)

	score_system = ScoreSystem.new()
	score_system.score_manager = score_manager
	score_system.game_manager = null

func after_each():
	score_manager.free()
	score_system.free()

# --- _award_to_majority ---

func test_award_single_owner_gets_full_points():
	score_system._award_to_majority({0: 1}, 6)
	assert_eq(score_manager.get_score(0), 6)

func test_award_tied_players_both_get_full_points():
	score_system._award_to_majority({0: 2, 1: 2}, 6)
	assert_eq(score_manager.get_score(0), 6)
	assert_eq(score_manager.get_score(1), 6)

func test_award_loser_gets_nothing():
	score_system._award_to_majority({0: 3, 1: 1}, 6)
	assert_eq(score_manager.get_score(0), 6)
	assert_eq(score_manager.get_score(1), 0)

func test_award_three_way_tie_all_get_full_points():
	score_system._award_to_majority({0: 2, 1: 2, 2: 2}, 9)
	assert_eq(score_manager.get_score(0), 9)
	assert_eq(score_manager.get_score(1), 9)
	assert_eq(score_manager.get_score(2), 9)

func test_award_empty_owners_does_nothing():
	score_system._award_to_majority({}, 10)
	assert_eq(score_manager.get_score(0), 0)
	assert_eq(score_manager.get_score(1), 0)

func test_award_accumulates_across_multiple_calls():
	score_system._award_to_majority({0: 1}, 4)
	score_system._award_to_majority({0: 1}, 2)
	assert_eq(score_manager.get_score(0), 6)

# --- _get_feature_type ---

func test_get_feature_type_road():
	var td = CarcassonneTileData.new()
	assert_eq(score_system._get_feature_type("road_0", td), "road")

func test_get_feature_type_city():
	var td = CarcassonneTileData.new()
	assert_eq(score_system._get_feature_type("city_0", td), "city")

func test_get_feature_type_field():
	var td = CarcassonneTileData.new()
	assert_eq(score_system._get_feature_type("field_0", td), "field")

func test_get_feature_type_other():
	var td = CarcassonneTileData.new()
	assert_eq(score_system._get_feature_type("monastery", td), "other")
	assert_eq(score_system._get_feature_type("center", td), "other")
