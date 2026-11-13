class_name RatingGoal
extends Goal
## A standing goal: keep the recent rating, the one the player is shown, at [member target]
## stars or more. It isn't met until [member min_rides] rides have been rated, so one lucky
## first ride doesn't meet it.

var target: float
var min_rides: int
## The recent rating, as last told.
var rating := 0.0
var rides := 0


func _init(stars: float, min_rated_rides := 1) -> void:
	target = stars
	min_rides = maxi(min_rated_rides, 1)


func get_text() -> String:
	return "Maintain %.1f rating" % target


## How close the rating is to the target, and 0 until enough rides are rated.
func get_progress() -> float:
	if rides < min_rides or target <= 0.0:
		return 1.0 if is_met() else 0.0
	return minf(rating / target, 1.0)


func is_met() -> bool:
	return rides >= min_rides and rating >= target


func is_standing() -> bool:
	return true


func _on_rating_changed(stars: float, count: int) -> void:
	if is_equal_approx(stars, rating) and count == rides:
		return
	rating = stars
	rides = count
	changed.emit()
