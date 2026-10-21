# Progression menu mock (2026-10-20)

Source of the mock Zach approved: https://claude.ai/artifact/LtuWdvQws3vYRxNccdWJ8V

- `*.dc.html`: one screen each at 1280x720 (the game's UI canvas is 800x450: scale by 0.625). Main = katana tree,
  Overview = combat chart, Adventure = swimming tree, Acrobatics, Defense, Loadout, Captain, Toast = the "new skill
  tree" banner. Layout data is in each file's `renderVals()`.
- `chrome.css`: the whimsical chrome (wooden beam, hanging sign tabs, rope, parchment, slate in rope, ribbons,
  star rules, wooden keycaps). The `.screen [style*=...]` rules round the cards' corners.
- `icons/`: the tab icons (crown, crossed swords, compass, chest) and the compass-rose emblem, 16 / 32 px pixel SVGs.
- `/_blob/...` urls in the html are the game's own 24 px skill icons (assets/textures/icons/skill_<id>.png) and
  weapon icons, uploaded to the mock.
