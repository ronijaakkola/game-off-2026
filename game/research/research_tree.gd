class_name ResearchTree
extends Resource
## A planet's research tree: the upgrades researched there, each placed by its tier and
## column, and linked to the ones it requires.

@export var upgrades: Array[Upgrade] = []
