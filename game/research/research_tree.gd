class_name ResearchTree
extends Resource
## A research tree: the upgrades for one part of the bus, each placed by its tier and
## column, and linked to the ones it requires. Every planet with a lab researches from
## every tree.

## What its column in the research screen is headed: the part of the bus it improves.
@export var title := ""
@export var upgrades: Array[Upgrade] = []
