# 02 — Dormant zones, caps and work counters

Status: ✅ done

Foothold's main performance device (analysis note 01 §9), here in its simplest form.

- A zone's garrison exists in the world only while a player aircraft is within `dynamic.wake_radius` (60 km) of it, or while it is the target of a sortie (tickets 03 to 05).
- It is removed when nobody has been within that radius for `dynamic.sleep_seconds` (600 s); its record keeps every unit, dead or alive, where it stood, so it comes back exactly as it was.
- Removed units are unregistered **before** `Group:destroy()`, so the removal can never read as a loss.
- At most `dynamic.max_awake_zones` (12) zones are awake; the nearest to a player win.
- One zone is woken per beat at most, so a player arriving does not spawn the whole front in one frame.
- Both the capture and the convoys keep working on a dormant zone: the capture looks at what is on the ground, not at the garrison.
- Work counters gain `awake zones`, `wakes`, `sleeps`; the admin radio command shows them.
- In episodic mode dormancy is off unless `dynamic.wake_radius` is set.

## Done when

Lua tests: wake by proximity, sleep after the delay, losses kept across a sleep, cap respected nearest first, no loss recorded by a sleep, one wake per beat.
In game: a zone far from the player shows on the map but has no unit (F10 view), and fills when the player approaches.
