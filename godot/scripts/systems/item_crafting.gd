class_name HeroItemCrafting
extends RefCounted

static func can_craft(run: HeroRun, id: String) -> bool:
	if run.phase != "shop" or not run.pending_branch.is_empty() or id not in run.guild_support.unlockedRecipeIds or not run.data.guildManagement.recipes.has(id): return false
	var recipe: Dictionary = run.data.guildManagement.recipes[id]
	var limit: Variant = run.data.items[recipe.resultItemId].maxStacks
	if limit != null and run.items.get(recipe.resultItemId,0) >= limit: return false
	for ingredient in recipe.ingredients:
		if run.items.get(ingredient,0) < recipe.ingredients[ingredient]: return false
	return true

static func craft(run: HeroRun, id: String) -> bool:
	if not can_craft(run,id): return false
	var recipe: Dictionary = run.data.guildManagement.recipes[id]
	var owned: Dictionary = run.items.duplicate()
	for ingredient in recipe.ingredients:
		owned[ingredient] -= recipe.ingredients[ingredient]
		if owned[ingredient] == 0: owned.erase(ingredient)
	owned[recipe.resultItemId] = owned.get(recipe.resultItemId,0)+1
	run.items = owned
	run.recalculate()
	run.event.emit("purchase")
	return true
