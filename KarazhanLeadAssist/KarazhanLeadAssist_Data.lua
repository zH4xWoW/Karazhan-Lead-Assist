local addonName, ns = ...

ns.data = {
    bosses = {
        {
            id = "attumen",
            name = "Attumen the Huntsman",
            aliases = {"Attumen", "Midnight"},
            assignLabels = {"Tank plan", "Curse / dispel plan", "Charge positioning"},
            sections = {
                {"Raid Lead Summary", "Phase 1 starts on Midnight. At 95% Attumen joins, then the pair merge when either reaches 25%. Keep Attumen faced away and get the raid ready for charge after the mount-up."},
                {"Tank", "Be ready to snap Attumen the instant he spawns. Face him away from the raid to stop Shadow Cleave clipping melee. After the mount-up, keep the boss stable and leave one far target in a safe charge lane."},
                {"Healer", "Watch the Attumen pickup and the mounted phase closely. Knockdown can create tank spikes, and Intangible Presence can hurt hit chance for players near the boss if you are running dispels / curse cleanup."},
                {"DPS / Utility", "Stay out of frontals. Do not stand in the charge lane unless assigned as the safe far target. Melee should be ready for the merge timing so they do not get clipped by movement or cleave."},
            },
            announce = {
                "Attumen: start on Midnight, tank snap Attumen immediately at 95%.",
                "Face boss away at all times and keep melee out of the front.",
                "Mounted phase: safe charge lane only; everyone else stay tucked in.",
            },
        },
        {
            id = "moroes",
            name = "Moroes",
            aliases = {"Moroes"},
            assignLabels = {"Tank / second threat", "CC / kill order", "Garrote plan"},
            sections = {
                {"Raid Lead Summary", "This fight is won before the pull: assign CC, assign kill order, and make sure two tanks sit at the top of threat for Gouge. Moroes will Vanish into Garrote and enrages at 30%."},
                {"Tank", "Main tank on Moroes, off tank stays second on threat for Gouge. Pick up broken CC or dangerous guests if needed. Call a taunt or backup if Gouge happens at a bad time."},
                {"Healer", "Be ready for Vanish into Garrote damage and for the 30% enrage. Track who gets Garrote and call external healing or personal cooldowns on low-health targets."},
                {"DPS / Utility", "Stick to the assigned kill / CC order. Priest and paladin-style guests are usually the first priority because of Mana Burn, heals, and utility. Do not overtake tank threat during Gouge windows."},
            },
            announce = {
                "Moroes: follow assigned CC and kill order.",
                "Two tanks stay top threat for Gouge; do not rip during Gouge windows.",
                "Watch Vanish + Garrote and be ready for enrage at 30%.",
            },
        },
        {
            id = "maiden",
            name = "Maiden of Virtue",
            aliases = {"Maiden", "Maiden of Virtue"},
            assignLabels = {"Spread pattern", "Cleanse / dispel", "Repentance recovery"},
            sections = {
                {"Raid Lead Summary", "Simple positioning fight. Spread around the room so Holy Wrath does not chain through the raid, and be ready to recover after Repentance."},
                {"Tank", "Keep Maiden centered and stable so the raid can stay spread. Avoid dragging her through the room and forcing healers into line-of-sight problems."},
                {"Healer", "Holy Fire targets need quick dispel / healing. Repentance can leave the tank briefly exposed, so pre-HoTs, shields, or a tremor / immunity plan help smooth the recovery."},
                {"DPS / Utility", "Keep your spread, do not stack the chain lightning-style Holy Wrath, and avoid drifting behind pillars where healers lose line of sight."},
            },
            announce = {
                "Maiden: spread around the room and keep line of sight clean.",
                "Do not chain Holy Wrath through the raid.",
                "Be ready for Repentance recovery and quick Holy Fire dispels.",
            },
        },
        {
            id = "opera",
            name = "Opera Event",
            aliases = {"Opera", "Big Bad Wolf", "Julianne", "Romulo", "The Crone"},
            assignLabels = {"Weekly event call", "Interrupt / CC plan", "Special movement"},
            sections = {
                {"Raid Lead Summary", "Opera rotates weekly between Big Bad Wolf, Romulo and Julianne, and Wizard of Oz. Scout the event, then load the matching assignment note before the pull."},
                {"Big Bad Wolf", "Red Riding Hood target kites immediately and never stops moving. Tremor Totem / Fear Ward can help with Terrifying Howl. Everyone else stays clear and lets the target run clean lanes."},
                {"Romulo & Julianne", "Interrupt Julianne's heal every time, dispel their buffs, face Romulo away from the raid, and finish both bosses within 15 seconds in the final phase."},
                {"Wizard of Oz", "Typical kill order: Dorothee, Tito if needed, Roar, Strawman, Tinhead, then Crone. Keep fire damage on Strawman for stuns, face Tinhead away, and dodge Cyclones on Crone."},
            },
            announce = {
                "Opera: confirm the weekly event before pull and swap to the matching plan.",
                "BBW = kite Red Riding Hood. R&J = interrupt heal + sync the kill. Oz = follow the marked kill order.",
            },
        },
        {
            id = "curator",
            name = "The Curator",
            aliases = {"Curator", "The Curator"},
            assignLabels = {"Spark / flare control", "Evocation burn plan", "Hateful Bolt target"},
            sections = {
                {"Raid Lead Summary", "Controlled add cleanup into an Evocation burn. Assign flare kill focus, keep the Hateful Bolt target healthy, then push hard during Evocation."},
                {"Tank", "Keep Curator planted. If you use a dedicated Hateful Bolt soaker or off-tank structure, confirm it before pull so healers know who is taking the extra Arcane hit."},
                {"Healer", "Astral Flares create steady raid damage, and Hateful Bolt can spike the second target on threat. Save mana and cooldowns so the group can fully capitalize on Evocation."},
                {"DPS / Utility", "Swap quickly to Astral Flares and return to boss only when the current flare dies. During Evocation, commit cooldowns and maximize damage."},
            },
            announce = {
                "Curator: hard swap to every Astral Flare.",
                "Keep the Hateful Bolt target healthy.",
                "Full burn and cooldowns during Evocation.",
            },
        },
        {
            id = "illhoof",
            name = "Terestian Illhoof",
            aliases = {"Illhoof", "Terestian Illhoof", "Kil'rek"},
            assignLabels = {"Sacrifice break team", "Imp control", "Kil'rek timing"},
            sections = {
                {"Raid Lead Summary", "The fight is about instant Sacrifice breaks, controlled imp splash damage, and using Kil'rek deaths to make boss burn windows cleaner."},
                {"Tank", "Pick up Illhoof and be ready to grab Kil'rek whenever he respawns. Position the boss so the raid can cleave imps without chaos."},
                {"Healer", "Watch the Sacrifice target first. If chains stay up too long the target dies fast. Raid damage rises as imps pile up, so call for AoE control if the room gets messy."},
                {"DPS / Utility", "Start by killing Kil'rek for the Broken Pact debuff, then prioritize every Sacrifice chain instantly. Cleave / AoE imps as assigned, but never at the cost of a slow chain break."},
            },
            announce = {
                "Illhoof: chains die instantly every time.",
                "Kill Kil'rek on spawn windows for the debuff.",
                "Control imp count and do not let Sacrifice sit.",
            },
        },
        {
            id = "aran",
            name = "Shade of Aran",
            aliases = {"Aran", "Shade of Aran"},
            assignLabels = {"Interrupt order", "Elemental control", "Flame Wreath reminder"},
            sections = {
                {"Raid Lead Summary", "This is an awareness and interrupt fight. The two raid-killing calls are Flame Wreath and the pull-slow-explosion combo; both need calm voice calls."},
                {"Tank", "No conventional tank job here. Be ready to help collect Water Elementals at 40% if your group is short on crowd control."},
                {"Healer", "Spot-heal Dragon's Breath and missile targets, and expect extra chaos when Water Elementals spawn. The room-wide pull into Arcane Explosion is the largest predictable burst window."},
                {"DPS / Utility", "Interrupt Fireball and Frostbolt as a priority. If you get Flame Wreath, do not move. On magnetic pull, instantly run to the room edge. Control or kill Water Elementals at 40%."},
            },
            announce = {
                "Aran: do not move on Flame Wreath.",
                "Run to the wall immediately after the pull + slow combo starts.",
                "Follow interrupt order and control elementals at 40%.",
            },
        },
        {
            id = "netherspite",
            name = "Netherspite",
            aliases = {"Netherspite"},
            assignLabels = {"Red beam rotation", "Blue beam rotation", "Green beam / backup"},
            sections = {
                {"Raid Lead Summary", "This is the most assignment-heavy encounter in Kara. You win by pre-assigning beam rotations before the pull and calling swaps cleanly during portal and banish phases."},
                {"Tank", "Red beam soakers need a clean rotation or emergency backup. If the red beam misses, boss damage and survivability become unstable quickly."},
                {"Healer", "Green beam can be used for throughput and mana, but the boss must never be allowed to soak it. Plan which healer helps with green support and who covers portal soakers."},
                {"DPS / Utility", "Blue beam usually needs 2-3 rotating soakers. Watch your stacks, move for Void Zones, and spread or out-range Netherbreath during banish. Remember threat resets after banish ends."},
            },
            announce = {
                "Netherspite: follow beam assignments exactly.",
                "Red tank soaks, blue rotates, green can never reach the boss.",
                "Banish phase: spread or range the breath, then reset for threat wipe.",
            },
        },
        {
            id = "chess",
            name = "Chess Event",
            aliases = {"Chess", "Chess Event", "Echo of Medivh"},
            assignLabels = {"King driver", "Healer piece coverage", "Backup callers"},
            sections = {
                {"Raid Lead Summary", "Not a conventional boss. Put your most confident callers on the king / major pieces, move forward with purpose, and focus on ending the match instead of over-microing every unit."},
                {"Tank / Caller", "Assign one primary shot-caller for movement and one backup in case a player gets knocked out of a piece or loses overview."},
                {"Raid", "Players controlling heal / support pieces should keep key frontliners active, but the raid should still play aggressively toward the enemy king instead of stalling the board."},
                {"Reminder", "If a player gets ejected, immediately re-enter a useful piece. Keep Medivh cheats from causing panic; recover and continue pressure."},
            },
            announce = {
                "Chess: follow the primary caller, keep pieces active, and push their king.",
                "If you get ejected, jump back into a useful piece immediately.",
            },
        },
        {
            id = "prince",
            name = "Prince Malchezaar",
            aliases = {"Prince", "Prince Malchezaar", "Malchezaar"},
            assignLabels = {"Infernal movement lane", "Enfeeble recovery", "Phase 3 healing"},
            sections = {
                {"Raid Lead Summary", "Prince is mostly positioning discipline. Keep the tank stable, give the raid clear infernal lanes, and call Enfeeble into Shadow Nova every time."},
                {"Tank", "Hold Prince where the raid has room to move as infernals land. Phase 2 hits harder because of Thrash, and Phase 3 can spike brutally if Amplify Damage lands on the tank."},
                {"Healer", "Enfeeble targets are at 1 HP and must be topped before Shadow Nova. In Phase 3, watch axe targets and any Amplify Damage on the tank or other players."},
                {"DPS / Utility", "After Enfeeble, get out of Shadow Nova range immediately. Respect infernal space all fight. In Phase 3, keep moving cleanly while the axes chase random players."},
            },
            announce = {
                "Prince: call every Enfeeble and get out for Shadow Nova.",
                "Respect infernal space and keep the movement lane clean.",
                "Phase 3: heavy healing on axe targets and any Amplify Damage tank.",
            },
        },
        {
            id = "nightbane",
            name = "Nightbane",
            aliases = {"Nightbane"},
            assignLabels = {"Fear / totem plan", "Skeleton stack / AoE", "Air phase tank target"},
            sections = {
                {"Raid Lead Summary", "Nightbane rewards clean phase calls. Ground phase is a dragon positioning check; air phase is about stacking correctly, gathering skeletons, and stabilizing the Smoking Blast target."},
                {"Tank", "Keep head and tail away from the raid so melee can work from the side. During air phase, be ready to organize skeleton pickup as Rain of Bones lands."},
                {"Healer", "The Smoking Blast target takes consistent punishment in the air phase. Assign focused healing there, then rotate back to raid stabilization once the skeleton pack is under control."},
                {"DPS / Utility", "Stay out of front and tail, dodge Charred Earth, and stack tightly under Nightbane in air phases so Rain of Bones spawns skeletons together for AoE."},
            },
            announce = {
                "Nightbane: side melee only; stay out of head and tail.",
                "Air phase: stack under boss so skeletons spawn together.",
                "Focused healing on Smoking Blast target and fast AoE on skeletons.",
            },
        },
    },
    trash = {
        {
            id = "stables",
            name = "Trash: Stables / Attumen Wing",
            aliases = {"Stables"},
            assignLabels = {"CC marks", "Fear plan", "Kill order"},
            sections = {
                {"What matters", "Spectral Chargers are dangerous because of Charge and Fear. Stable Hands bring Knockdown, armor reduction, and heals. This area is much easier if the raid stacks correctly and interrupts the healers."},
                {"Raid lead calls", "Mark Stable Hands for early kill or CC, call stack-behind on Chargers, and confirm Tremor / Fear Ward coverage before larger pulls."},
            },
            announce = {
                "Stable trash: stack behind chargers, stop fears, and kill / CC Stable Hands first.",
            },
        },
        {
            id = "ballroom",
            name = "Trash: Ballroom / Moroes Wing",
            aliases = {"Ballroom"},
            assignLabels = {"CC marks", "Mind control plan", "Tank danger"},
            sections = {
                {"What matters", "Retainers can mind control and strip buffs, Phantom Valets hit extremely hard, and Skeletal Waiters can leave the zero-armor Brittle Bones debuff on tanks."},
                {"Raid lead calls", "Pull cleanly into line-of-sight where possible, hard-focus Retainers, and watch for tanks carrying Brittle Bones into Valet damage."},
            },
            announce = {
                "Ballroom trash: Retainers die first, watch MCs, and respect Brittle Bones on tanks.",
            },
        },
        {
            id = "maidenhall",
            name = "Trash: Maiden Hallway",
            aliases = {"Maiden Hallway", "Holy Hallway"},
            assignLabels = {"Pull path", "Caster interrupts", "Patrol watch"},
            sections = {
                {"What matters", "This wing is lighter than ballroom trash, but sloppy pulls still punish weak interrupts and bad patrol timing."},
                {"Raid lead calls", "Pause for patrols, pull casters into clean line-of-sight positions, and keep the raid compact so nobody face-pulls ahead of the tank."},
            },
            announce = {
                "Maiden trash: slow and clean pulls, LOS casters, and wait for patrol timing.",
            },
        },
        {
            id = "operahall",
            name = "Trash: Opera Hall / Backstage",
            aliases = {"Opera Hall", "Backstage"},
            assignLabels = {"CC marks", "Patrol timing", "Do not overpull"},
            sections = {
                {"What matters", "This is one of the easiest places to lose a run to accidental overpulls. The area is packed, patrols overlap, and careless movement before or after Opera can snowball quickly."},
                {"Raid lead calls", "Set a strict stop point, mark patrol-sensitive pulls, and move only after the whole room is stable. Remind the raid not to drift forward during loot or roleplay."},
            },
            announce = {
                "Opera trash: hold position, respect patrols, and do not drift into extra packs.",
            },
        },
        {
            id = "curatorhall",
            name = "Trash: Menagerie / Curator Hall",
            aliases = {"Curator Hall", "Menagerie"},
            assignLabels = {"Safe room", "Pull-back point", "Reflect warning"},
            sections = {
                {"What matters", "The room before Curator punishes players who wander in early, and several mobs in this stretch hit hard or reflect specific damage types."},
                {"Raid lead calls", "Use a defined safe room / pull-back point, tell the raid not to step into Curator's room early, and warn DPS to stop into reflect if their health dips."},
            },
            announce = {
                "Curator hall: pull back to the safe room and stop attacking into reflects when called.",
            },
        },
        {
            id = "library",
            name = "Trash: Library / Shade Wing",
            aliases = {"Library", "Shade Wing"},
            assignLabels = {"Interrupt marks", "Sheep / banish", "Spacing"},
            sections = {
                {"What matters", "Caster-heavy pulls can get ugly if interrupts fail or the raid clumps too hard into splash and random damage."},
                {"Raid lead calls", "Assign kicks before the pull, use crowd control on extra casters, and keep ranged from stacking on top of each other without reason."},
            },
            announce = {
                "Library trash: kicks assigned, CC extras, and keep spacing clean.",
            },
        },
        {
            id = "netherspiteroom",
            name = "Trash: Netherspite Wing",
            aliases = {"Netherspite Room", "Nether Wing"},
            assignLabels = {"Mark priority", "Void zone watch", "Healer mana pace"},
            sections = {
                {"What matters", "The wing itself is manageable, but fatigue and sloppy movement make players eat unnecessary damage before one of Kara's most assignment-heavy bosses."},
                {"Raid lead calls", "Use marks even on simple pulls, avoid rushing between packs, and top everyone before engaging Netherspite so beam assignments start clean."},
            },
            announce = {
                "Netherspite wing: stay sharp, avoid lazy movement damage, and reset fully before boss.",
            },
        },
        {
            id = "brokenstair",
            name = "Trash: Broken Stair / Prince Ramp",
            aliases = {"Broken Stair", "Prince Ramp"},
            assignLabels = {"Tank spacing", "Cleave warning", "Stun / control"},
            sections = {
                {"What matters", "The final stair and ramp trash punishes tanks standing together and melee drifting into frontals or cleaves."},
                {"Raid lead calls", "Separate tanks when needed, keep the raid out of cleave angles, and do not rush the staircase where line of sight and pathing can become messy."},
            },
            announce = {
                "Prince ramp trash: tanks keep spacing, raid stays out of cleaves, and do not rush the stairs.",
            },
        },
        {
            id = "balcony",
            name = "Trash: Master's Terrace / Nightbane Setup",
            aliases = {"Balcony", "Nightbane Setup", "Master's Terrace"},
            assignLabels = {"Urn carrier", "Nightbane yes/no", "Pre-pull reset"},
            sections = {
                {"What matters", "Nightbane is optional, so confirm whether you are doing him before the raid moves out. If yes, make sure the Blackened Urn user is present and the raid is fully reset before the summon."},
                {"Raid lead calls", "Call for the urn carrier, mana break, soulstones / buffs, and exact stack point for the first air phase so the pull starts organized."},
            },
            announce = {
                "Nightbane setup: confirm urn carrier, full reset, then summon on call.",
            },
        },
    },
    utilities = {
        {
            id = "weeklyprep",
            name = "Utility: Weekly Prep",
            aliases = {"Weekly Prep", "Prep"},
            assignLabels = {"Consumables / summons", "Raid roles", "Optional boss check"},
            sections = {
                {"Checklist", "Confirm attuned players or door coverage, soulstones, healthstones, reagents, shards, raid markers, and whether Nightbane is on the plan for the night."},
                {"Role setup", "Pre-assign tanks, off-tanks, interrupt rotations, dispels, crowd control, and any special jobs before the first pull so you are not rebuilding structure at Moroes and Netherspite."},
            },
            announce = {
                "Weekly prep: confirm tanks, healers, interrupts, CC, and Nightbane plan before first pull.",
            },
        },
        {
            id = "raidflow",
            name = "Utility: Suggested Raid Flow",
            aliases = {"Raid Flow", "Route"},
            assignLabels = {"Break point", "Opera scout", "Nightbane slot"},
            sections = {
                {"Suggested order", "Typical order is Attumen, Moroes, Maiden, Opera, Curator, Illhoof, Shade, Netherspite, Chess, Prince, with Nightbane slotted in when your group is ready and has the summon."},
                {"Leader tips", "Use the easier early wings to identify weak interrupts, healer mana stability, and tank threat before committing to Moroes guests, Aran discipline, or Netherspite beam rotations."},
            },
            announce = {
                "Route check: early wings first, then deeper bosses; slot Nightbane only if the raid is ready.",
            },
        },
        {
            id = "fastcalls",
            name = "Utility: Fast Reminder Calls",
            aliases = {"Fast Calls", "Reminders"},
            assignLabels = {"Callout 1", "Callout 2", "Callout 3"},
            sections = {
                {"Useful universal calls", "Melee out of frontals. Hold for patrol. Stop on threat. Kick order now. Spread. Collapse. Do not move. Reset and drink. Marked target dies first."},
                {"Use", "Save your team-specific short calls in the custom notes box for this utility entry and announce them before recurring trouble pulls."},
            },
            announce = {
                "Fast calls loaded: use your saved short reminders here for recurring mistakes.",
            },
        },
    },
}
