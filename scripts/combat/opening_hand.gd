class_name OpeningHand
extends RefCounted
## Exact uniform sampler over legal physical five-card subsets. Count groups
## by cost, weight each composition by its number of possible combinations.

static func shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap = items[i]
		items[i] = items[j]
		items[j] = swap

static func choose(n: int, k: int) -> int:
	if k < 0 or k > n:
		return 0
	var result: int = 1
	for i in range(1, mini(k, n - k) + 1):
		result = int(result * (n - i + 1) / i)
	return result

static func sample(deck: Array, rng: RandomNumberGenerator) -> Array:
	var groups: Array = [[], [], []]
	for card in deck:
		var cost: int = card.definition.cost
		groups[0 if cost == 1 else (1 if cost <= 3 else 2)].append(card)
	var compositions: Array = []
	var total: int = 0
	for a in range(1, 6):
		for b in range(0, 6 - a):
			var c: int = 5 - a - b
			if a + b < 2:
				continue
			var weight: int = choose(groups[0].size(), a) * choose(groups[1].size(), b) * choose(groups[2].size(), c)
			if weight > 0:
				total += weight
				compositions.append([a, b, c, total])
	if total == 0:
		return []
	var roll: int = rng.randi_range(1, total)
	var counts: Array = []
	for composition in compositions:
		if roll <= composition[3]:
			counts = composition
			break
	var result: Array = []
	for group in range(3):
		shuffle(groups[group], rng)
		result.append_array(groups[group].slice(0, counts[group]))
	shuffle(result, rng)
	return result
