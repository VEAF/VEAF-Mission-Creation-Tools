# "Fire at Adler" — what we learned from your Cowork session

Hi Trakdah,

Thanks for sending the export of your Claude Cowork session (25 October 2026, VEAF tools 6.31.4, 46 minutes).
It is the first full mission built through Cowork that we have been able to read end to end, and it taught us a lot.
Here is what we found, what we are changing in the tools, and some advice for your next sessions.

## What went well

- The assistant followed the VEAF authoring guide in the right order: one question at a time, three scenarios to choose from, nothing written before you approved one.
- It measured distances on the map, said when a figure was an estimate (the 420 kt cruise speed), and checked how much each SAM site could see of the route.
- It read back its own work: it turned the briefing deck into images, looked at every page, and caught the early-warning radar sitting on the Adler runway.
- Its final report was honest about what had been checked and what had not.

The mission built and validated with no errors, together with a 17-page briefing deck.

## What to check before flying it

Nothing in this mission has been tested in DCS yet.
Before you put it on a server, please check these points in the Mission Editor or in game:

1. **The fuel depot is not a real place on the map.** The assistant could not find the Adler depot by name, used a position from memory, then moved the six tanks to a spot of clear ground nearby. Move them to a credible location if you care about realism.
2. **The route goes out over the sea at wave-top height.** A Viggen pilot would more likely use the valleys and hills to stay hidden. The tools can measure what each radar sees along a route, but the assistant never compared that route with one that follows the terrain. Your assistant said so itself afterwards.
3. **Every blue aircraft type can take a slot at Senaki**, including warbirds and modern jets like the F-16 or the Apache, in a 1987 mission. This is a gap in the tools (see below).
4. **Units may sit in trees or buildings**: the tools had no clear-ground data around Sochi for the SAM sites and the radar, and the tanks were never checked.
5. **In-game behaviour**: whether Skynet wakes the SAM sites, whether the MiG-23s engage, whether the end-of-mission message appears, and whether the F10 map drawings show.
6. **Security is off.** That is the right choice for a mission played outside the VEAF servers (see "Security" below).

## What we are changing in the VEAF tools

Your session showed five real defects, and we are adding a few improvements you or your assistant asked for.
All of it goes into one batch of work:

- **Briefing pictures in the mission you fly.** The briefing tool wrote its maps into an intermediate file, not into the `missions\…_dawn.miz` you actually fly. They will go into every weather variant.
- **Two route points with the same name.** COAST (going out) and COAST (coming back) were silently merged into one, and a point of the route disappeared. This will now stop the build with a clear message.
- **`~` in a folder path** (as in `~/Documents`) was not understood. It will be.
- **The "Diversion fields" line of the deck** listed the departure field itself. It will not, and the assistant will be able to set the list.
- **Aircraft slots that match the era.** A Cold War mission will only offer aircraft of that era, like the AI aircraft already do.
- **Security, explained in plain words** (see below), and a command to turn a password into the form the mission needs, without the password ever going through the AI.
- **Briefing pages in the kneeboard.** The maps (overview and one per objective), a flight card with the route and frequencies, and the target coordinates, as kneeboard pages in every aircraft.
- **Choosing how good the enemy AI is**: a question when the mission is designed, applied to enemy aircraft and ground units.
- **Better route planning.** For a low-level mission, the assistant will be asked to propose a route that matches how the aircraft really flies, and to compare what the radars see on two candidate routes before proposing one. Low-level missions will get the topographic map by default.
- **A single action to write a route**, which sets every point on the ground and refuses duplicate names, instead of the assistant editing the route file by hand.

Your assistant also suggested an interactive planning map, where you would drag the route points yourself.
It is a good idea, but it depends on what Cowork can display, which nobody has checked yet, so we are leaving it for later.

## Not a defect of the tools

The "Access denied" errors at the start were not caused by the tools.
The assistant tried to create the mission in the Documents folder of another Windows account on your PC, not yours.
The VEAF tools run with your own Windows account, so they cannot write there.
Connecting `D:\OneDrive\DCS\Missions\VEAF-Ai` was the right fix.

## Advice for using Cowork with the VEAF tools

Cowork is an unusual setup for the VEAF tools: the assistant runs in the cloud, while the VEAF tools run on your PC.
It works, but it helps to know how the two halves talk to each other.

1. **Connect your mission folder before asking for a mission.** Click "Add folder" in the Claude desktop app and pick an empty folder, for example `Documents\VEAF\Missions`. The assistant can only see the files of the folders you connect.
2. **Tell the assistant where to create the mission**, with the full path of that folder. Otherwise it guesses, and in your session it guessed the wrong Windows account.
3. **Folder access works in two places.** Connecting a folder lets the cloud assistant read it. The VEAF tools write with your own Windows rights. A folder must be both connected and writable by your account.
4. **Say how the sortie should be flown.** If you have an idea of the profile ("terrain masking through the valleys", "pop-up from the sea"), say it when you choose the scenario. The assistant brings general knowledge, you bring the pilot's eye.
5. **Ask for the topographic map** for any low-level mission, until the tools do it by default.
6. **Check the result in DCS before sharing it.** The assistant cannot launch DCS from Cowork; the list it gives you at the end is the list to check.
7. **Keep the session export.** Cowork has no `/export` command, but asking the assistant to export the session as JSON works, as you did. It is the best thing to send us when something goes wrong.

## Security, in plain words

The VEAF security module locks the sensitive F10 and map-marker commands: spawning units, teleporting, destroying.

- On the **VEAF servers**, known pilots pass without a password because the server keeps a list of them.
- On **any other server**, nobody is on that list, so only someone with a password can use those commands.
- The password shipped with the VEAF tools by default is public, so it protects nothing.

So for a mission played outside the VEAF servers, either turn security off, as you did, or set your own passwords.
The command that turns a password into the hash the mission needs is coming with the next batch.

Thanks again for the export — it is exactly the kind of feedback that makes the tools better.
