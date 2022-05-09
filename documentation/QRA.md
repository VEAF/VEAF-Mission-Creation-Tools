# Quick Reaction Aircraft feature

## Synopsis

This object simulates aircraft groups that are on alert somewhere, and can react quickly to enemy aircrafts entering a specific airspace (hence, the name).

It uses a state machine :

![qra-state-machine](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/master/documentation/qra-flowchart.jpg?raw=true "qra-flowchart.jpg")

The last conditions ("All enemy groups left the zone" and "Activation time is up") are optional

## Usage

An instance must be created, initialized, configured and started before the state machine is ready.

All the "set" functions return self, and so they are easily chainable ; e.g. 
```lua
  VeafQRA.new()
  :setName("QRA/Maykop")
  :setZoneCenterFromCoordinates("U37TEK8250048000")
  :setZoneRadius(91440) -- 300,000 feet
  :setGroupsToDeployByEnemyQuantity(1, { "QRA-Maykop-1" }) -- 1 and more
  :setGroupsToDeployByEnemyQuantity(3, { "QRA-Maykop-1", "QRA-Maykop-2" }) -- 3 and more
  :setGroupsToDeployByEnemyQuantity(5, { "QRA-Maykop-1", "QRA-Maykop-2", "QRA-Maykop-3" }) -- 5 and more
  :setCoalition(coalition.side.RED)
  :addEnnemyCoalition(coalition.side.BLUE)
  :setReactOnHelicopters() -- reacts when helicopters enter the zone
  :setDelayBeforeRearming(15) -- 15 seconds before the QRA is rearmed
  :setNoNeedToLeaveZoneBeforeRearming() -- the enemy does not have to leave the zone before the QRA is rearmed
  :start()
```

## Metadata

Each QRA instance must have a name ; it's only used in logging and as a default description.

Set it with `VeafQRA:setName(value)` ; e.g. `myQra:setName("KutaisiQRA")`


It's also possible to set a description that is used when emitting messages, such as when the state of the QRA instance changes. 

If not set, the `name` attribute is used as a default description.

Set it with `VeafQRA:setDescription(value)` ; e.g. `myQra:setDescription("Kutaisi defense forces")`

## Messaging

When the state of the QRA changes, messages are emitted (displayed on screen). 

This is entirely optional, to disable them all use `VeafQRA:setSilent()` ; e.g. `myQRA:setSilent()`

The default messages are superceeded with the following functions :

* `VeafQRA:setMessageStart(value)`
* `VeafQRA:setMessageDestroyed(value)`
* `VeafQRA:setMessageReady(value)`

E.g. `myQRA:setMessageReady("Kutaisi forces are ready to engage enemies !")`

## Coalitions

Coalitions are used to define who is allied and who is enemy for this QRA (see state machine diagram at the top of this page).

Set the allied coalition with `VeafQRA:setCoalition(value)`, and the enemy coalitions with repeated uses of `VeafQRA:addEnnemyCoalition(value)`.

E.g.

```lua
  :setCoalition(coalition.side.RED)
  :addEnnemyCoalition(coalition.side.BLUE)
  :addEnnemyCoalition(coalition.side.NEUTRAL)
```

## QRA zone

The QRA features are centered around a zone, defined either with a DCS trigger zone in the mission editor (use `VeafQRA:setTriggerZone(value)`), or with a center point (use either `VeafQRA:setZoneCenter(value)` or `VeafQRA:setZoneCenterFromCoordinates(value)`) and radius in meters (use `VeafQRA:setZoneRadius(value)`)

E.g.

```lua
  :setZoneCenterFromCoordinates("U37TEK8250048000")
  :setZoneRadius(91440) -- 300,000 feet
```

or

```lua
  :setTriggerZone("KutaisiQRA")
```

## QRA reaction aircrafts groups

The aircraft that will be spawned when an enemy group enters the zone must exist in the mission, as "late activated" groups.

### Add groups

To add a group, use `VeafQRA:addGroup(value)` once for each group you want to add.

```lua
  :addGroup("QRA-Maykop-1")
  :addGroup("QRA-Maykop-2")
  :addGroup("QRA-Maykop-3")
```

Alternatively, you can make repeated uses of `VeafQRA:setGroupsToDeployByEnemyQuantity(enemyNb, groupsToDeploy)` to change the groups that will be spawned based on the number of enemy aircraft entering the zone.

E.g. 

```lua
  :setGroupsToDeployByEnemyQuantity(1, { "QRA-Maykop-1" }) -- 1 and more
  :setGroupsToDeployByEnemyQuantity(3, { "QRA-Maykop-1", "QRA-Maykop-2" }) -- 3 and more
  :setGroupsToDeployByEnemyQuantity(5, { "QRA-Maykop-1", "QRA-Maykop-2", "QRA-Maykop-3" }) -- 5 and more
```

In this example, 

* for 5 or more groups, the "QRA-Maykop-1", "QRA-Maykop-2", and "QRA-Maykop-3" groups will be spawned
* between 3 and 4 groups, the "QRA-Maykop-1" and "QRA-Maykop-2" groups will be spawned
* between 1 and 2 groups, only the "QRA-Maykop-1" group will be spawned

### Random groups

Randomizable variants of these two functions exist : `VeafQRA:addRandomGroup(value)` and `VeafQRA:setRandomGroupsToDeployByEnemyQuantity(enemyNb, groupsToDeploy)`

The group(s) name(s) parameter are replaced with a set of other parameters :

* a list of groups that can be spawned, sorted by difficulty 
* a number (default 1) that represents the number of groups that will be spawned, randomly chosen amongst the groups of the list
* a number (default 0) that defines the bias ; this is simply a value that will be added (it can be negative) to the randomly generated number, when choosing a group in the list, effectively biasing the choice towards an easiest choice (left of the list, for a negative bias) or a toughest choice (right of the list, for a positive bias)

__In this example, we spawn one group from the list, with no bias__

```lua
:addRandomGroup({ "QRA-Maykop-1", "QRA-Maykop-2", "QRA-Maykop-3" })
```

__In this example, we spawn two groups from the list, with no bias__

```lua
:addRandomGroup({ "QRA-Maykop-1", "QRA-Maykop-2", "QRA-Maykop-3" }, 2)
```

__This example is there to explain the bias mecanism__

```lua
:addRandomGroup({ "QRA-Maykop-1", "QRA-Maykop-2", "QRA-Maykop-3" }, 2, -1)
```

We'll spawn two groups ; for each spawn, we'll roll a dice between 1 and 3 (the lenght of the list), and add the bias (-1, it is negative) to get the actual dice. Then we'll pick the group that corresponds to this dice in the list, with a limit of course (all under 1 become 1, and all above 3 become 3).

In this example, we could have used the `{ "QRA-Maykop-1", "QRA-Maykop-2" }, 2, 0` parameters for the same effect. There is little interest in using the bias, except to keep the same list for multiple cases and use the bias to change the outcome, as in the next example.

__In this other example, we use the mecanism to increase the difficulty of the spawns when more enemy groups are in the zone__

```lua
  :setRandomGroupsToDeployByEnemyQuantity(1, { "QRA-Maykop-1", "QRA-Maykop-2", "QRA-Maykop-3" }, 2, -1) -- 1 and more
  :setRandomGroupsToDeployByEnemyQuantity(3, { "QRA-Maykop-1", "QRA-Maykop-2", "QRA-Maykop-3" }, 2, 0) -- 3 and more
  :setRandomGroupsToDeployByEnemyQuantity(5, { "QRA-Maykop-1", "QRA-Maykop-2", "QRA-Maykop-3" }, 2, 1) -- 5 and more
```

## QRA behavior

As said in the synopsis, the condition for rearming the QRA is that all the enemy groups leave the zone (or that they are destroyed).

This is optional, when using `VeafQRA:setNoNeedToLeaveZoneBeforeRearming()` the QRA is rearmed as soon as the last allied response group is destroyed.

Also optional, a delay (in seconds) can be added before rearming the QRA by using `VeafQRA:setDelayBeforeRearming(value)`

It is also possible to react not only to enemy aircrafts entering the zone, but also enemy helicopters, by using `VeafQRA:setReactOnHelicopters()`

## Other options

There is a possibility to randomize the location of the allied response groups spawns by using `VeafQRA:setRespawnRadius(value)` ; they'll spawn in the set radius (in meters) around the point where they are set in the mission editor.
