extends GdUnitTestSuite

# Tests run on desktop, where Online must stay offline: these pin that local runs, CI and
# check.py never reach Talo, and that every call is safe offline. The online path needs a web
# build, so it's checked by hand (docs/online.md, Trying it out).

var _access_key: String


func before_test() -> void:
	_access_key = Talo.settings.access_key


func after_test() -> void:
	Talo.settings.access_key = _access_key


func test_offline_without_an_access_key() -> void:
	Talo.settings.access_key = ""
	assert_bool(Online.is_enabled()).is_false()


func test_offline_outside_web_builds_even_with_a_key() -> void:
	Talo.settings.access_key = "a-key"
	assert_bool(Online.is_enabled()).is_false()
	assert_bool(Online.is_identified()).is_false()


func test_calls_are_safe_offline() -> void:
	Talo.settings.access_key = "a-key"
	Online.track("level_completed", {"level": 3})
	Online.add_stat("deaths")
	Online.flush()
	Online.set_player_name("Bob")
	assert_str(Online.get_player_name()).is_empty()
	assert_object(await Online.submit_score("high-scores", 120.0)).is_null()
	assert_array(await Online.get_scores("high-scores")).is_empty()
