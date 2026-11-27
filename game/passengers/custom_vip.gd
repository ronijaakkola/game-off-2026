class_name CustomVip
extends Resource
## A hand-written [Vip]: who they are and what they say as they call. Whatever is left
## empty is rolled as any VIP's is, and so are their looks, where they wait and the stops
## of their tour. [VipCalls] draws one now and then in place of a rolled VIP, at most one
## accepted in a star system.

## What goes before their name ("Admiral"), or empty for one of the VIPs' titles.
@export var title := ""
## Their name without the title, or empty for an ordinary one.
@export var name := ""
## What they say as they call, in BBCode as any transmission's text, or empty for one of
## the VIPs' lines. [code]{pick_up}[/code] becomes the planet they wait at and
## [code]{stops}[/code] their stops in order ("Giant, Ember and Moon").
@export_multiline var text := ""
