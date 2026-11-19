class_name ResearchTree
extends Resource
## A research tree: the upgrades for one part of the bus, each placed by its tier and
## column, and linked to the ones it requires. Every planet with a lab researches from
## every tree.

## What its column in the research screen is headed: the part of the bus it improves.
@export var title := ""
## The icon before its title, white so the tree's colour tints it.
@export var icon: Texture2D
## The race whose colours its tiles, lines and chip show in. Only the look: research points
## are one kind, and every tree takes them.
@export var palette := Race.Type.BLUE
@export var upgrades: Array[Upgrade] = []
