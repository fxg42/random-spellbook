-- Window datasources used by comboxes. Initialized on desktop init.
local sources = {}
local schools = {}
local damageTypes = {}
local wizardNames = {}

-- databaseNode from the window. Initialized on button click and used by
-- database accessors.
local databaseNode

--
-- Initializers and hooks
--

function onInit()
  Interface.onDesktopInit = onDesktopInit
end

function onDesktopInit()
  addButtonToItemsWindow()
  buildReferenceTables()
end

-- Adds a "Spellbook" button on the Items window, next to the "Forge" button.

function addButtonToItemsWindow()
  local aGMListButtons = LibraryData.getRecordTypeInfo("item").aGMListButtons
  table.insert(aGMListButtons, "button_item_spellbook")
end

-- Initializes datasources for the comboboxes by scanning and parsing the list
-- of spells. Can only be called after module load or after desktop init.
-- Damage types are taken from DataCommon module and the wizardNames table is
-- also initialized.

function buildReferenceTables()
  local uniqueSchools = {}
  local uniqueSources = {}
  
  forEachSpell(function(spell)
    for _,source in pairs(StringManager.split(DB.getValue(spell, "source", ""), ",", true)) do
      uniqueSources[source] = true
    end
    uniqueSchools[DB.getValue(spell, "school", "")] = true
  end)

  for source, _ in pairs(uniqueSources) do
    table.insert(sources, source)
  end
  for school, _ in pairs(uniqueSchools) do
    table.insert(schools, school)
  end

  table.sort(sources)
  table.insert(sources, 1, "")

  table.sort(schools)
  table.insert(schools, 1, "")

  table.sort(damageTypes)
  table.insert(damageTypes, 1, "")

  damageTypes = DataCommon.dmgtypes

  wizardNames = StringManager.splitByPattern(Interface.getString("spellbooks_wizard_names"), "%s+", true)
  shuffle(wizardNames)
end

--
-- Window Accessors
--

function getSources()
  return sources
end

function getSchools()
  return schools
end

function getDamageTypes()
  return damageTypes
end

--
-- Window Event Handlers
--

function onNameRollClick(window)
  databaseNode = window.getDatabaseNode()
  DB.setValue(databaseNode, "name", "string", getRandomSpellbookName())
end

function onGenerateClick(window)
  databaseNode = window.getDatabaseNode()
  
  local spells = selectRandomSpells()
  local item = generateSpellbook(spells)
  local itemNode = addSpellbookToCampaign(item)
  Interface.openWindow("item", itemNode)
end

function onResetClick(window)
  databaseNode = window.getDatabaseNode()
  setInputsToDefaultValues()
end

--
-- Spell selection
--

-- Sets the "selected" property of each spell partition by shuffling, ranking
-- and sorting the spells. Spells with the highest rank will be selected first.
-- Returns a mapping identical to partitionSpellsByLevel's

function selectRandomSpells()
  local selectedSpellsByLevel = {}
  for level, spells in ipairs(partitionSpellsByLevel()) do
    local selectedSpells = {}
    local reqCount = getRequiredSpellCountByLevel(level)
    if #spells > 0 and reqCount > 0 then
      shuffle(spells)
      rankSpells(spells)
      reverseSortBy(spells, "rank")
      selectedSpells = pluck(take(spells, reqCount), "node")
    end
    table.insert(selectedSpellsByLevel, level, selectedSpells)
  end
  return selectedSpellsByLevel
end

-- Scans the list of spells and outputs a mapping of spells by their spell
-- level. Each item value holds a numerical rank, the raw spell data and a
-- list of selected spells for the spellbook.

function partitionSpellsByLevel()
  local spellsByLevel = {}
  forEachSpell(function(spell)
    local level = DB.getValue(spell, "level", 0)
    if not spellsByLevel[level] then
      spellsByLevel[level] = {}
    end
    table.insert(spellsByLevel[level], {
      ["rank"] = 0,
      ["node"] = spell,
    })
  end)
  return spellsByLevel
end

-- Scans the list of spells. For each, updates its "rank" property. Each
-- matching preference increments the spell's rank by the associated
-- weight.

function rankSpells(spells)
  local preferredSource = getPreferredSource()
  local preferredSchool = getPreferredSchool()
  local preferredDamageType = getPreferredDamageType()

  local relativeSourceWeight = getRelativeSourceWeight()
  local relativeSchoolWeight = getRelativeSchoolWeight()
  local relativeDamageTypeWeight = getRelativeDamageTypeWeight()

  for _, spell in pairs(spells) do
    if preferredSource ~= "" then
      local source = DB.getValue(spell.node, "source", "")
      if source:find(preferredSource) then
        spell.rank = spell.rank + relativeSourceWeight
      end
    end

    if preferredSchool ~= "" then
      local school = DB.getValue(spell.node, "school", "")
      if school == preferredSchool then
        spell.rank = spell.rank + relativeSchoolWeight
      end
    end

    if preferredDamageType ~= "" then
      local description = DB.getValue(spell.node, "description", "")
      if description:find(preferredDamageType) then
        spell.rank = spell.rank + relativeDamageTypeWeight
      end
    end     
  end
end

-- Returns a record that will be used to create an Item record. Uses the list
-- of spells to generate a formatted text description with links.

function generateSpellbook(spellsByLevel)
  local description = [[
    <h>Description</h>
    <p>The spellbook contains the following spells:</p>
  ]]
  for level, spells in ipairs(spellsByLevel) do
    if #spells > 0 then
      description = description .. [[
        <p><b>]] .. level .. (level == 1 and "st" or (level == 2 and "nd" or (level == 3 and "rd" or "th"))) .. [[ level spells:</b></p>
        <linklist>
      ]]
      for _, spell in ipairs(spells) do
        description = description .. [[
          <link class="reference_spell" recordname="]] .. spell.getNodeName() .. [[">
            <b>Spell: </b>]] .. DB.getValue(spell, "name", "") .. [[
          </link>
        ]]
      end
      description = description .. [[</linklist>]]
    end
  end
  description = description .. [[
    <p><b>Spellbook Notes</b></p>
    <p>Essential for wizards, a spellbook is a leather-bound tome with 100 blank vellum pages suitable for recording spells.</p>
  ]]

  return {
    ["name"] = getName(),
    ["nonid_name"] = "Spellbook",
    ["type"] = "Wondrous Item",
    ["rarity"] = "Common",
    ["weight"] = 3,
    ["cost"] = "50 - 100 gp",
    ["description"] = description,
  }
end

--
-- Database Accessors
--

function getName()
  return DB.getValue(databaseNode, "name", "")
end

function getPreferredSource()
  return DB.getValue(databaseNode, "preferredSource", "")
end

function getPreferredSchool()
  return DB.getValue(databaseNode, "preferredSchool", "")
end

function getPreferredDamageType()
  return DB.getValue(databaseNode, "preferredDamageType", "")
end

function getRequiredSpellCountByLevel(level)
  return DB.getValue(databaseNode, "level"..level, 0)
end

function getRelativeSourceWeight()
  return DB.getValue(databaseNode, "sourceRelativeWeight", 1)
end

function getRelativeSchoolWeight()
  return DB.getValue(databaseNode, "schoolRelativeWeight", 1)
end

function getRelativeDamageTypeWeight()
  return DB.getValue(databaseNode, "damageTypeRelativeWeight", 1)
end

function setInputsToDefaultValues()
  DB.setValue(databaseNode, "name", "string", "")

  DB.setValue(databaseNode, "preferredSource", "string", "Wizard")
  DB.setValue(databaseNode, "preferredSchool", "string", "")
  DB.setValue(databaseNode, "preferredDamageType", "string", "")

  DB.setValue(databaseNode, "sourceRelativeWeight", "number", 1)
  DB.setValue(databaseNode, "schoolRelativeWeight", "number", 1)
  DB.setValue(databaseNode, "damageTypeRelativeWeight", "number", 1)

  DB.setValue(databaseNode, "level1", "number", 4)
  DB.setValue(databaseNode, "level2", "number", 3)
  DB.setValue(databaseNode, "level3", "number", 3)
  DB.setValue(databaseNode, "level4", "number", 3)
  DB.setValue(databaseNode, "level5", "number", 1)
  DB.setValue(databaseNode, "level6", "number", 0)
  DB.setValue(databaseNode, "level7", "number", 0)
  DB.setValue(databaseNode, "level8", "number", 0)
  DB.setValue(databaseNode, "level9", "number", 0)
end

-- Uses the spellbook record returned by "generateSpellbook" to create an
-- Item record.

function addSpellbookToCampaign(spellbook)
  local itemNode = DB.createChild("item")
  
  DB.setValue(itemNode, "locked", "number", 0)
  DB.setValue(itemNode, "nonid_name", "string", spellbook.nonid_name)
  DB.setValue(itemNode, "name", "string", spellbook.name)
  DB.setValue(itemNode, "type", "string", spellbook.type)
  DB.setValue(itemNode, "rarity", "string", spellbook.rarity)
  DB.setValue(itemNode, "weight", "number", spellbook.weight)
  DB.setValue(itemNode, "cost", "string", spellbook.cost)
  DB.setValue(itemNode, "description", "formattedtext", spellbook.description);
  
  return itemNode
end

--
-- Utilities
--

-- Returns a random spellbook name.

function getRandomSpellbookName()
  return getRandomItem(wizardNames) .. "'s Spellbook"
end

-- Scans the list of spells and calls the given function for each.

function forEachSpell(f)
  local spellMappings = LibraryData.getMappings("spell");
  for _, spellMapping in ipairs(spellMappings) do
    for _, spell in pairs(DB.getChildrenGlobal(spellMapping)) do
      f(spell)
    end
  end
end

-- Shuffles the given list in-place

function shuffle(list)
  for i = #list, 2, -1 do
    local j = math.random(i)
    list[i], list[j] = list[j], list[i]
  end
end

-- Returns a random item from list

function getRandomItem(list)
  local idx = math.random(#list)
  return list[idx]
end

-- Returns the first n items from a list

function take(list, n)
  local sub = {}
  for i, item in ipairs(list) do
    if i > n then break end
    table.insert(sub, item)
  end
  return sub
end

-- Extracts a property from every item in the list

function pluck(list, prop)
  return fmap(list, function(item) return item[prop] end)
end

-- Collects the results of applying function f to every item in list

function fmap(list, f)
  local mapped = {}
  for _, item in ipairs(list) do
    table.insert(mapped, f(item))
  end
  return mapped
end

-- Sorts a list in-place by a given property value

function reverseSortBy(spells, prop)
  table.sort(spells, function(a, b) return a[prop] > b[prop] end)
end