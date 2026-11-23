extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const BEST_TIME_PATH := "user://figueiras-times.cfg"
const MEDALS := {
	"alameda": Vector3(35.0, 25.0, 20.5), "mirante": Vector3(73.0, 54.0, 42.0),
	"radares": Vector3(180.0, 230.0, 290.0), "contorno": Vector3(9.0, 5.0, 2.2),
	"oficinas": Vector3(40.0, 29.0, 24.0), "horto": Vector3(55.0, 42.0, 32.5),
	"mercado": Vector3(24.0, 18.0, 14.5),
}
const PACE_NOTES := {
	"mirante": [[106.0, "Direita de raio curto na subida"], [257.0, "Esquerda na crista do Mirante"],
		[346.0, "Entrada da galeria em descida"], [503.0, "Direita longa na descida"]],
	"horto": [[94.0, "Esquerda longa em subida"], [124.0, "Direita fecha junto à encosta"],
		[198.0, "Direita na Casa das Sementes"]],
	"mercado": [[55.0, "Esquerda fecha no fim da descida"], [75.0, "Curva sob a cobertura"],
		[128.0, "Esquerda fechada em subida"]],
	"galeria": [[24.0, "Esquerda sob a galeria"], [48.0, "Saída da galeria em subida"]],
	"estacao": [[15.0, "Entrada da plataforma coberta"], [40.0, "Esquerda longa atrás do galpão"],
		[66.0, "Esquerda fecha no pátio"]],
	"passo": [[94.0, "Direita longa em subida"], [136.0, "Direita na rampa mais íngreme"],
		[200.0, "Direita sobre a crista"], [249.0, "Esquerda abre para uma descida forte"],
		[317.0, "Esquerda longa em descida"], [366.0, "Grampo à direita antes do Mirante"]],
}


static func catalog() -> Array[Dictionary]:
	var lane := Layout.AVENUE + Layout.AVENUE_MEDIAN_HALF + Layout.AVENUE_LANE
	var alameda := Layout.urban_routes()[1]
	var ridge := Layout.scenic_routes()[0]
	var lake := Layout.scenic_routes()[1]
	var horto := Layout.urban_routes()[Layout.HORTO_ROUTE]
	var market := Layout.urban_routes()[Layout.MERCADO_ROUTE]
	var result: Array[Dictionary] = [
		{
			"id": "alameda", "title": "Sprint da Alameda", "type": "Tempo", "limit": 155.0,
			"description": "Avenida, curva da estação e chegada na rua sul.",
			"fixed": [[Vector2(-151, lane), Vector2.RIGHT, Layout.AVENUE_LANE], [Vector2(-56, lane), Vector2.RIGHT, Layout.AVENUE_LANE]],
			"curve": alameda, "stations": [33.0, 79.0, 137.0], "curve_entry": 11.0,
			"hints": ["Cruze a largada na avenida", "Siga pela avenida", "Vire à direita na Alameda", "Contorne o Jardim da Estação", "Siga até a rua sul"],
			"labels": ["LARGADA", "AVENIDA", "ALAMEDA", "JARDIM", "CHEGADA"],
		},
		{
			"id": "mirante", "title": "Subida do Mirante", "type": "Tempo", "limit": 180.0,
			"description": "Suba a serra, atravesse a galeria e desça até a Vila.",
			"fixed": [], "curve": ridge, "stations": [26.0, 131.0, 258.0, 337.0, 405.0, ridge.length - 28.0], "curve_entry": 26.0,
			"hints": ["A largada fica no acesso oeste", "Suba as primeiras curvas", "Passe pelo mirante", "Mantenha a linha para entrar na galeria", "Saia da galeria e contorne a encosta", "Desça rumo à Vila"],
			"labels": ["LARGADA", "SUBIDA", "MIRANTE", "GALERIA", "ENCOSTA", "CHEGADA"],
		},
		{
			"id": "radares", "title": "Radares da Avenida", "type": "Velocidade", "limit": 90.0,
			"description": "Some a velocidade registrada em três pontos da avenida.",
			"fixed": [[Vector2(-180, lane), Vector2.RIGHT, Layout.AVENUE_LANE], [Vector2(-92, lane), Vector2.RIGHT, Layout.AVENUE_LANE],
				[Vector2(31, lane), Vector2.RIGHT, Layout.AVENUE_LANE], [Vector2(171, lane), Vector2.RIGHT, Layout.AVENUE_LANE]],
			"curve": null, "stations": [], "curve_entry": 0.0,
			"hints": ["Largada no trecho oeste da avenida", "Cruze o radar antes da praça", "Siga até a saída da praça", "Último radar antes da saída leste"],
			"labels": ["LARGADA", "RADAR 1", "RADAR 2", "RADAR 3"],
		},
		{
			"id": "contorno", "title": "Contorno das Águas", "type": "Regularidade", "limit": 120.0, "target": 57.0,
			"description": "Complete o contorno o mais perto possível de 57 segundos. Chegar cedo também custa pontos.",
			"fixed": [], "curve": lake, "stations": [25.0, lake.length * 0.33, lake.length * 0.55, lake.length * 0.74, lake.length - 21.0], "curve_entry": 25.0,
			"hints": ["Largada no acesso leste da avenida", "Siga pela orla", "Contorne o reservatório", "Acerte o ritmo na descida", "Chegue próximo de 57 segundos"],
			"labels": ["LARGADA", "ORLA", "RESERVATÓRIO", "DESCIDA", "CHEGADA"],
		},
		{
			"id": "oficinas", "title": "Travessia das Oficinas", "type": "Tempo", "limit": 90.0,
			"description": "Contorne a quadra e passe entre os galpões. A curva de entrada exige uma freada forte.",
			"fixed": [[Vector2(-181, -174.2), Vector2.RIGHT, 1.8], [Vector2(-126.8, -157), Vector2.DOWN, 4.0],
				[Vector2(-126.8, -94), Vector2.DOWN, 4.0], [Vector2(-82.0, -52.2), Vector2.RIGHT, 1.8]],
			"preview": [Vector2(-181, -174.2), Vector2(-137, -174.2), Vector2(-130, -173), Vector2(-126.8, -164),
				Vector2(-126.8, -157), Vector2(-126.8, -66), Vector2(-124, -54), Vector2(-116, -52.2), Vector2(-82.0, -52.2)],
			"curve": null, "stations": [], "curve_entry": 0.0,
			"hints": ["Largada no alto da Vila", "Vire à direita no pórtico", "Atravesse as oficinas", "Saia à esquerda das oficinas, rumo à praça"],
			"labels": ["LARGADA", "PÓRTICO", "OFICINAS", "CHEGADA"],
		},
		{
			"id": "horto", "title": "Volta do Horto", "type": "Tempo", "limit": 135.0,
			"description": "Entre pelo acesso oeste da rua do meio. Contorne a encosta e volte pela rua de cima.",
			"fixed": [], "curve": horto, "stations": [20.0, horto.length * 0.28, horto.stop_station, horto.length * 0.79, horto.length - 12.0], "curve_entry": 20.0,
			"hints": ["Entre no acesso oeste da rua do meio", "Siga a subida", "Passe em frente à Casa das Sementes", "Mantenha a linha na curva da encosta", "Retorne à Vila pela rua de cima"],
			"labels": ["LARGADA", "SUBIDA", "HORTO", "ENCOSTA", "CHEGADA"],
		},
		{
			"id": "mercado", "title": "Circuito do Mercado", "type": "Tempo", "limit": 85.0,
			"description": "Desça atrás do mercado, atravesse os galpões cobertos e retorne à avenida.",
			"fixed": [], "curve": market, "stations": [19.0, market.length * 0.34, market.length * 0.52, market.length * 0.73, market.length - 13.0], "curve_entry": 19.0,
			"hints": ["Entre na Rua do Mercado", "Reduza na descida", "Passe pela cobertura", "Contorne os galpões", "Volte à avenida"],
			"labels": ["LARGADA", "DESCIDA", "MERCADO", "GALPÕES", "CHEGADA"],
		},
	]
	var streets := Layout.urban_routes()
	if streets.size() > 5:
		result.append(_street_trial("galeria", "Galeria da Praça", streets[4], 4.0,
			["Um trecho coberto entre a avenida e a rua do meio.", "Siga pelo acesso da praça", "Passe sob a galeria", "Atravesse o pátio", "Saia na rua do meio"],
			Vector3(16.0, 11.6, 8.5)))
		result.append(_street_trial("estacao", "Pátio da Estação", streets[5], 5.0,
			["Passe pelo carregamento da estação e retorne ao bairro pela saída sul.", "Siga pelo acesso da estação", "Cruze a cobertura da estação", "Faça a curva do pátio", "Retorne pela saída sul"],
			Vector3(16.0, 13.0, 11.0)))
	var scenic := Layout.scenic_routes()
	if scenic.size() > Layout.PASSO_ROUTE:
		var road := scenic[Layout.PASSO_ROUTE]
		result.append(_street_trial("passo", "Travessia do Passo", road, 13.0,
			["Do Horto ao Mirante, pela crista e pelos cortes de rocha.", "Acesse o Passo pelo Horto", "Reduza no primeiro contorno", "Acerte a linha na crista", "Cruze a chegada antes do Mirante"],
			Vector3(52.0, 40.0, 33.5)))
	var district := Layout.district_routes()
	var avenue := district[Layout.Baixada.AVENIDA]
	var trial := _street_trial("baixada", "Avenida da Baixada", avenue, 36.0,
		["Percorra a Baixada de ponta a ponta, pela ponte e pela subida dos sobrados.",
			"Pegue o acesso oeste da Estrada do Vale", "Mantenha o ritmo na descida",
			"Cruze a ponte da Baixada", "Suba até a saída do bairro"], Vector3(85.0, 65.0, 52.0))
	trial.stations[-1] = avenue.length - 33.0
	result.append(trial)
	var factory := district[Layout.Baixada.FABRICA]
	var canal := district[Layout.Baixada.CANAL]
	var crossing := district[Layout.Baixada.TRAVESSA]
	result.append({
		"id": "arroio", "title": "Rota Livre do Arroio", "type": "Tempo", "limit": 180.0,
		"description": "Passe pela Fiação, pela Ponte da Usina e pelo Canal na ordem que quiser. Depois cruze a chegada.",
		"free_checkpoints": true, "medals": Vector3(101.0, 79.0, 63.0),
		"fixed": [_gate(avenue, 43.0), _gate(factory, 68.0), _gate(crossing, Layout.district_bridges()[crossing]),
			_gate(canal, canal.length * 0.74), _gate(avenue, avenue.length - 39.0)],
		"curve": null, "stations": [], "curve_entry": 0.0,
		"hints": ["Acesse a Baixada pelo lado oeste", "Fiação", "Ponte da Usina", "Canal", "Suba até a saída leste"],
		"labels": ["LARGADA", "FIAÇÃO", "PONTE DA USINA", "CANAL", "CHEGADA"],
	})
	return result


static func _gate(road: RefCounted, station: float) -> Array:
	return [road.point_at(station), road.direction_at(station), road.half_width + 0.15]


static func _street_trial(id: String, title: String, road: RefCounted, entry: float,
		copy: Array[String], medals: Vector3) -> Dictionary:
	return {
		"id": id, "title": title, "type": "Tempo", "limit": maxf(85.0, medals.x * 2.0),
		"description": copy[0], "fixed": [], "curve": road, "curve_entry": entry,
		"stations": [entry, road.length * 0.32, road.length * 0.63, road.length - 8.0],
		"hints": copy.slice(1), "labels": ["LARGADA", "SETOR 1", "SETOR 2", "CHEGADA"],
		"medals": medals,
	}


static func target(event: Dictionary, rank: int, wet: bool) -> float:
	var thresholds: Vector3 = event.get("medals", MEDALS.get(event.id, Vector3.ZERO))
	var value := thresholds[rank - 1]
	if not wet:
		return value
	match event.type:
		"Tempo": return value * 1.12
		"Velocidade": return value * 0.94
		_: return value


static func medal(event: Dictionary, score: float, wet: bool) -> int:
	if not is_finite(score) or score < 0.0:
		return 0
	for rank in [3, 2, 1]:
		var threshold := target(event, rank, wet)
		var achieved: bool = score >= threshold if event.type == "Velocidade" else score <= threshold
		if threshold > 0.0 and achieved:
			return rank
	return 0


static func medal_name(rank: int) -> String:
	return ["Concluída", "Bronze", "Prata", "Ouro"][rank]


static func pace_note(event: Dictionary, point: Vector2, speed: float) -> String:
	if not PACE_NOTES.has(event.id):
		return ""
	var projection: Vector3 = event.curve.project(point)
	if projection.z > event.curve.half_width + 0.75:
		return ""
	var lead := clampf(speed * 2.7, 16.0, 66.0)
	for note: Array in PACE_NOTES[event.id]:
		var remaining: float = note[0] - projection.x
		if remaining < -3.0 or remaining > lead:
			continue
		return "%s · %d m" % [note[1], roundi(remaining / 5.0) * 5] if remaining >= 7.5 else note[1]
	return ""


static func record_key(event: Dictionary, wet: bool) -> String:
	var key := "best_seconds"
	if event.type == "Velocidade":
		key = "best_kmh"
	elif event.type == "Regularidade":
		key = "best_deviation"
	return key + ("_wet" if wet else "")


static func format_score(event: Dictionary, value: float) -> String:
	if value < 0.0:
		return "—"
	match event.type:
		"Velocidade":
			return "%d km/h somados" % roundi(value)
		"Regularidade":
			return "%.2f s de diferença" % value
		_:
			var ms := roundi(value * 1000.0)
			return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]
