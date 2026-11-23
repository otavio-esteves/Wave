extends RefCounted

enum Retail {
	NEIGHBORHOOD,
	GROCERY,
	GLAZED,
	CIVIC,
	SERVICE,
}

# The avenue has four different sequences of plot widths and uses. The older
# frontage by the cinema reads as a single street wall. Deeper forecourts and
# larger plots distinguish the eastern additions from the original center.
const AVENUE_PLOTS := {
	Vector2i(0, 1): [
		[1.00, "PADARIA IPÊ", "cream", 2, 1.95],
		[0.75, "ARMARINHO", "sage", 1, 1.95],
		[1.39, "CINE FIGUEIRAS", "terracotta", 3, 2.6],
		[1.04, "CORREIOS DA VILA", "plaster", 2, 2.15],
		[0.82, "FARMÁCIA IPÊ", "brick", 2, 1.95],
		[0.91, "LIVRARIA", "cream", 2, 1.95],
		[0.99, "CAFÉ DA PRAÇA", "sage", 2, 2.55],
	],
	Vector2i(2, 1): [
		[1.00, "MÓVEIS DA SERRA", "plaster", 2, 1.8],
		[1.23, "FARMÁCIA ESTAÇÃO", "cream", 4, 2.5],
		[0.69, "COSTURA", "blue", 1, 1.8],
		[1.45, "GALERIA DO RELÓGIO", "brick", 4, 3.15],
		[1.08, "CASA ELÉTRICA", "plaster", 3, 1.8],
		[0.90, "MERCEARIA", "sage", 2, 1.8],
		[0.95, "PAPELARIA", "cream", 2, 1.8],
	],
	Vector2i(1, 2): [
		[0.97, "FLORICULTURA", "sage", 1, 3.0],
		[1.23, "ARMAZÉM DO BAIRRO", "cream", 2, 1.9],
		[0.80, "BARBEARIA", "plaster", 2, 1.9],
		[1.00, "CAFÉ DO HORTO", "brick", 2, 2.55],
		[1.10, "SEBO DA ALAMEDA", "cream", 3, 2.2],
		[0.90, "PADARIA DO LARGO", "terracotta", 2, 2.55],
	],
	Vector2i(2, 2): [
		[1.05, "FERRAGENS", "brick", 2, 2.0],
		[0.85, "OFICINA", "sage", 1, 4.0],
		[1.15, "CASA DO PÃO", "cream", 3, 2.2],
		[1.07, "COOPERATIVA DO VALE", "plaster", 4, 2.0],
		[0.76, "CHAVEIRO", "terracotta", 1, 2.0],
		[1.04, "DROGARIA DO PÁTIO", "plaster", 3, 2.7],
		[1.08, "MERCEARIA DA ESTAÇÃO", "blue", 2, 2.0],
	],
}

const WALLS := [
	["plaster", "cream", "brick", "plaster", "sage", "plaster", "terracotta", "cream"],
	["cream", "plaster", "cream", "brick", "sage", "terracotta", "plaster", "cream"],
	["sage", "cream", "plaster", "brick", "plaster", "blue", "plaster", "cream"],
]


static func retail_treatment(shop: String, use: String) -> Retail:
	if shop in ["CORREIOS DA VILA", "CINE FIGUEIRAS", "GALERIA DO RELÓGIO"]:
		return Retail.CIVIC
	if shop in ["OFICINA", "FERRAGENS", "CASA ELÉTRICA"]:
		return Retail.SERVICE
	if use == "market":
		return Retail.GROCERY
	if use == "pharmacy" or shop == "MÓVEIS DA SERRA":
		return Retail.GLAZED
	return Retail.NEIGHBORHOOD


static func plot_widths(schedule: Array, count: int, total: float, seed: int, even: bool) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	var weight_sum := 0.0
	for index in count:
		var weight := 1.0
		if not schedule.is_empty():
			weight = schedule[index][0]
		elif not even:
			weight += 0.19 * sin(index * 2.13 + seed * 1.42) + 0.07 * cos(index * 3.63 + seed)
		widths.append(weight)
		weight_sum += weight
	for index in widths.size():
		widths[index] *= total / weight_sum
	return widths
