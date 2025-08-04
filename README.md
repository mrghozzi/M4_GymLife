# M4_GymLife - QBCore Gym System

## Description
`M4_GymLife` is a QBCore resource that provides a comprehensive in-game gym system, allowing players to improve their physical skills like stamina and health through exercises at various gym locations.

## Features
- **Multiple Gym Locations:** Includes predefined gym locations (Vespucci Beach, Downtown, Premium Gym) with expansion capability.
- **Variety of Exercises:** Each location offers unique exercises (push-ups, weight lifting, treadmill, yoga) with specific XP gains for each skill.
- **Membership System:** Players can purchase monthly memberships or pay per exercise session.
- **Skill Progression:** Improves player stamina and health skills with configurable maximum caps for each skill.
- **Cooldown System:** Prevents players from exercising too frequently.
- **NPC Trainers:** Non-player character trainers at gym locations.
- **Compatibility:** Fully compatible with QBCore and supports `qb-target` for interaction.

## Requirements
- [QBCore Framework](https://github.com/qbcore-framework/qb-core)
- [qb-menu](https://github.com/qbcore-framework/qb-menu)
- [qb-target](https://github.com/qbcore-framework/qb-target) (optional but recommended for interaction)

## Installation
1. Place the `M4_GymLife` folder in your QBCore resources folder (`resources/[qb]/`).
2. Add `ensure M4_GymLife` to your `server.cfg` file.
3. (Optional) If using `qb-target`, ensure it's enabled in `config.lua`.

## Configuration
Nearly all aspects of the resource can be customized via `config.lua`:
- **`Config.GymLocations`:** Define gym locations, coordinates, prices, and available exercises.
- **`Config.MembershipPrice` and `Config.MembershipDuration`:** Adjust membership cost and duration.
- **`Config.RequireMembership`:** Set whether membership is required for exercises.
- **`Config.SkillCaps`:** Set maximum caps for stamina and health skills.
- **`Config.Locale`:** Change resource language (default is English).
- **`Config.UseTarget`:** Enable/disable `qb-target` integration.
- **`Config.ProgressBar`:** Customize exercise progress bar.
- **`Config.NPCTrainers`:** Configure NPC trainers.

## Usage
1. Go to one of the gym locations defined in `config.lua`.
2. Interact with the interaction point (usually by pressing `E` or using `qb-target`).
3. Choose to purchase membership or select an exercise.
4. Complete the progress bar to finish the exercise and improve your skills.

## Support My Work 💖
If you enjoy this script and want to support my work, you can donate here:

- ☕ [Support me on Ko-fi](https://ko-fi.com/mrghozzi)
- 💸 [Support me on Ba9chich](https://ba9chich.com/en/mrghozzi)

## License 📄

This script is provided as-is with no warranty. You may modify it for personal use. Do not re-upload or sell without permission.