# Random Spellbooks

Fantasy Grounds Extension for the 5E ruleset that adds the option of creating
random spellbooks. The main use case is generating random loot for wizard PCs.

### How

The "Items" window now has a "Spellbooks" button next to the "Forge" button.

The Random Spellbook window allows the DM to specify:
- a name for the spellbook;
- a way of generating a random spellbook name;
- spell selection preferences and weights;
- the number of spells per spell levels to select.

![random-spellbook-1](https://user-images.githubusercontent.com/425363/130239583-514f0cba-8fe5-4a61-9a13-ede2c88ae91c.png)

The theme used in this screenshot is [SirMotte's Hearth](https://github.com/SirMotte/FGU-Theme-Hearth/releases).

### Ranked Spell Selection

When selecting spells, the generator will first shuffle the list of spells. It
will then rank each spell according to the set of chosen preferences. If a
spell matches the preference, the associated weight is added to the spell's
rank. Ranked spells are then reverse sorted by rank and the target number of
spells per spell level are added to the new spellbook.

### Why

I primarily wanted to learn how GUI programming works in FGU (windows,
templates, anchors, etc) and starting a new campaign with a wizard PC gave
me an excuse!