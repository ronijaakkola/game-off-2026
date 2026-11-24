# Alien voice clips

One folder per race: `blue/`, `orange/`, `green/`. Mono, dry, normalised, silence trimmed, `.ogg`. Any pitch shift or ring-mod is baked in before export: the web build has no bus effects.

## File names

`<race>_<kind><number>.ogg`, the number zero-padded to two digits: `b_b01.ogg`, `o_q02.ogg`, `g_s03.ogg`.

| Race letter | Race |
|---|---|
| `b` | Blue |
| `o` | Orange |
| `g` | Green |

| Kind letter | Kind | Plays |
|---|---|---|
| `b` | blip | One as each word of three or more letters starts |
| `q` | question end | On the word before a `?`, timed to end as the mark shows |
| `e` | exclamation end | On the word before a `!` |
| `l` | long clip (a longer blip) | At the start of a line, and sometimes at a comma or a full stop |
| `a` | annoyed stinger | When a transmission opens or the player answers, in an annoyed mood |
| `h` | happy stinger | The same, happy |
| `s` | scared stinger | The same, scared |
| `k` | kicked | When a passenger of the race is kicked off the bus: it plays once at the caller's pitch times `kicked_pitch`, and fades out over `kicked_fade` |

The number only tells clips of a kind apart. Takes of one blip are numbered on like any other, and the game treats every clip of a kind alike.

The letter after the race is the kind, so `b_b01` is a Blue blip and `o_b01` an Orange blip.

Each race's folder gets a `CREDITS.md` for where its clips came from.

## Using the clips

`voice.gd` (`Voice`) holds a race's clips and how they are strung together; `blue.tres` is Blue's. To add a clip, drag it into the matching list in the resource (blips, questions, exclaims, longs, stingers). To add a race, make its `.tres` the same way and add it to `VOICES` in `voice_speaker.gd`.

Each caller gets one of the race's `voice_count` pitch steps between `pitch_min` and `pitch_max`, picked from their name, so callers of a race sound clearly different. Blips are tied to words and chosen to fit the time before the next word; `blip_speed` plays them faster (and higher, since the web has no time-stretch), and `max_overlap` sets how far two clips may stack.

The voice lab tunes the delivery: **Debug panel (F2) › Voice lab** on the main menu. Its Copy button puts the values on the clipboard to set in the resource. The mixer (**Debug panel (F2) › Mixer**) sets how loud each race's voice is, and plays lines in it.
