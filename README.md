# MOONAR RESYNTH — update channel

This public repository currently hosts the MOONAR RESYNTH updater and versioned REAPER Lua interface under `moonar/`.

- Latest version manifest: [moonar/latest.txt](moonar/latest.txt)
- Updater for macOS / REAPER: [moonar/MOONAR_UPDATE.lua](moonar/MOONAR_UPDATE.lua)
- Release sources: [moonar/releases/](moonar/releases/)

The updater downloads only the companion Lua user interface, verifies its SHA-256 hash, checks version numbers, backs up the previous Lua controller, and leaves JSFX audio engines and user preset files untouched.

**Caution:** This is an experimental audio plugin under active development. Its current audio behavior on the user's REAPER installation has not been verified. This public update channel does not provide signed application releases.

The updater operates within REAPER on macOS. Its initial installation is required once; future revisions can be checked from the MOONAR GUI Update button.
