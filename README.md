# GMod-Nextbots
Nextbot entities for use in Garry's Mod (also known as GMod/Gmod). Code in Lua. Entities not currently available on the steam workshop, but you can try them yourself by copying the appropriate folder from this repository into your steamapps\common\GarrysMod\garrysmod\addons folder, then spawning them in using the spawn menu (you can find them in "Abyss Nextbots" under NPCs).

In the modern Garry's Mod community "nextbot" specifically refers to entities with a 2D image who generally chase you around a map. A craze began online (somewhere in September?) around these nextbots, leading to a wide variety of new nextbots being created with various themes and behaviours. In general, the complexity of nextbot behaviour has increased with time. I was inspired to have a go at creating my own. I had no clue how Garry's Mod addons were created but figured it would be an interesting challenge that might result in an exciting addon other people can play with one day.

I didn't know any Lua before starting this project. I learnt by analysing the code for Smiley, Terminus, Gargitron and other nextbots, and looking up anything I didn't understand/wanted clarified.

My general approach to each nextbot was to copy the files of another nextbot (originals are credited), then sift through each file and edit where appropriate. Due to this methodology most glitches I fix are glitches left over from the original nextbots.

Details on development process to be added - including development of images and audio.

# Abyss
Heavily based off of "Smiley (NEXTBOT)" by 󠀡󠀡LΛVΛ. Smiley is a basic nextbot. Image and audio changed. Code is entirely identical to Smiley's, save for the following changes:

local MUSIC_CUTOFF_DISTANCE = 2000000 (from 20000)

local MUSIC_abyss_PANIC_COUNT = 1 (from 8)

Abandoned in favour of working on Abyssal.

# Abyssal
Heavily based off of "Terminus Nextbot" by syhgma, which itself is based off of "Gargitron NextBot" by Gargin. Terminus is a "stalker" nextbot, with behaviour more complex than many nextbots currently available. Image and audio changed. Initial commit of code included some minor differences to Terminus' code, mostly relating to how (and what) information is printed to the console. Another notable change is a fix to how Terminus was coded to count escaped chases - it was double counting escaped chases.

At this point in development Abyssal and Terminus are relatively different experiences - they share the same basic "idea" but not much beyond that.

Comments with notation --. are my own. Any other notation currently means the comment was made by a previous developer.

Abyssal is now developed enough to be considered "version 1".

# Links

Demonstration videos:

Abyssal Demonstration - Stalking, Hiding, Killing

https://www.youtube.com/watch?v=IrWNbzbCA4Q

Abyssal Demonstration - Escaping a Chase

https://www.youtube.com/watch?v=fOjAJmsitmQ

Abyssal Demonstration - Enraged Mode

https://www.youtube.com/watch?v=MWa-uWLxJYA

Nextbots:

Smiley (NEXTBOT): https://steamcommunity.com/sharedfiles/filedetails/?id=1639300664

Terminus Nextbot: https://steamcommunity.com/sharedfiles/filedetails/?id=2873467078

Gargitron NextBot: https://steamcommunity.com/sharedfiles/filedetails/?id=2868173930
