class_name RatingGoal
extends Goal
## A standing goal: keep the average rating at [member target] stars or more. It isn't met
## until [member min_rides] rides have been rated, so one lucky first ride doesn't meet it.

var target: float
var min_rides: int
var average := 0.0
var rides := 0


func _init(stars: float, min_rated_rides := 1) -> void:
	target = stars
	min_rides = maxi(min_rated_rides, 1)


func get_text() -> String:
	return "Keep a %.1f-star rating" % target


## How close the average is to the target, and 0 until enough rides are rated.
func get_progress() -> float:
	if rides < min_rides or target <= 0.0:
		return 1.0 if is_met() else 0.0
	return minf(average / target, 1.0)


func is_met() -> bool:
	return rides >= min_rides and average >= target


func is_standing() -> bool:
	return true


func _on_rating_changed(stars: float, count: int) -> void:
	if is_equal_approx(stars, average) and count == rides:
		return
	average = stars
	rides = count
	changed.emit()
