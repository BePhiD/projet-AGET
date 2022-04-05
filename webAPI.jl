#=
API pour le système de création automatique d'emploi du temps (écrit en julia)
Auteur : Philippe Belhomme
Dates de création : lundi 27 décembre 2021
  de modification : mardi 15 février 2022
=#

using Genie, Genie.Router, Genie.Renderer.Html, Genie.Requests, Genie.Renderer.Json
import JSON: parse                      # module supplémentaire à installer
include("CONSTANTES.jl")         # pour disposer des constantes de l'application
include("PlanningSemaine.jl")           # pour affecter un créneau dans un x.dat
include("bddPlanificationSemaine.jl")   # pour gérer la base de données

# Info trouvée notamment sur :
# https://docs.juliahub.com/Genie/8eazC/0.31.5/guides/Simple_API_backend.html
# et...
# https://api.jquery.com/jquery.getjson/
route("/constantes") do
	# Récupère des infos CONSTANTES pour construire la page web et les
	# retourne au format JSON
	Genie.Renderer.Json.json( Dict("HEUREDEB" => string(HEUREDEB),
	           "NBCRENEAUX" => string(NBCRENEAUX),
			   "NBJOURS" => string(NBJOURS)) )
end

# Route récupérant l'état de TOUS les créneaux d'une ressource pour une semaine
# l'URL d'appel sera du type :
# http://serveur:8000/lectureDesCreneaux?ressource=belhomme&semaine=38
route("/lectureDesCreneaux") do
	# Récupère le nom de la ressource et le numéro de la semaine.
	ressource = params(:ressource, "?")
	semaine   = params(:semaine, "?")      # !!! de type String
	if semaine == "?"
		return    # pour précompilation...
	end
	P = lecturePlanningDeRessource(ressource, Base.parse(Int, semaine))
	if P == -1
		# La ressource ou la semaine n'était pas valide, quitte avec "erreur"
		return Genie.Renderer.Json.json( Dict("etat" => "erreur") )
	end
	#= Construit un dictionnaire avec comme clés les numéros de créneaux (au
	   sens de la page web, donc entre 1 et NBJOURS * NBCRENEAUX) et leur état
	   (booléen True si créneau libre, False si occupé) =#
	D = Dict()     # dictionnaire vide au départ
	for i in 1:NBJOURS * NBCRENEAUX
		# On va connaître l'état du créneau : occupé (false)/non occupé (true).
		jour, debut = convPosWebEnTupleJourDeb(i)
		D[i] = P[jour, debut]
	end
	return Genie.Renderer.Json.json( Dict("etat" => D) )
end

# Route modifiant l'état des créneaux d'une ressource pour une semaine donnée
# l'URL d'appel sera du type :
# http://serveur:8000/affecteLesCreneaux?ressource=belhomme&semaine=38&liste=1,2,...
route("/affecteLesCreneaux", method = "GET") do
	# Récupère le nom de la ressource, le numéro de la semaine et la liste des
	# numéros de créneaux à basculer comme "occupés". Les autres seront donc
	# considérés comme "libres".
	ressource = params(:ressource, false)
	semaine   = params(:semaine, false)
	if semaine == "?"
		return    # pour précompilation...
	end
	semaine = Base.parse(Int, semaine) # passage de String à Int64
	liste = params(:liste, false)     # chaine de numéros séparés par une ','
	# TODO: tester si au moins une des 3 valeurs est false pour quitter...

	#= Il faut maintenant modifier chaque créneau dans le fichier xxx.dat de la
	   ressource xxx et re-sérialiser ce fichier sur le disque. =#
	obj = deserialize(open(REPERTOIRE_DATA * SEP * ressource * ".dat", "r"))
	obj[semaine] = LibereSemaine(obj[semaine])    # vide par défaut la semaine
	for creneau in split(liste, ',')              # créneau est de type String
		# Convertir un numéro de créneau vers un tuple (jour, deb)
		jour, deb = convPosWebEnTupleJourDeb(Base.parse(Int, creneau))
		AffecteCreneau(obj[semaine], jour, deb, 1)
	end
	io = open(REPERTOIRE_DATA * '/' * ressource * ".dat", "w")
    serialize(io, obj)
    close(io)
end

#= Route permettant de charger depuis une base de données les créneaux de la
   semaine demandée
   L'URL d'appel sera du type :
   http://serveur:8000/selectCreneaux?semaine=38
=#
route("/selectCreneaux", method = "GET") do
	semaine = params(:semaine, false)
	if semaine == "?"
		return    # pour précompilation...
	end
	Base.parse(Int, semaine)    # String vers Int
	# Appelle la fonction spécifique du module bddPlanificationSemaine.jl
	df = selectCreneauxBDD(semaine)
	# Place chaque ligne de la BDD dans une chaîne simulant un tableau de JSON
	chJSON = "["
	for L in eachrow(df)
		ch = """{"uuid": "$(L.uuid)",
		         "tab": "$(L.tab)",
				 "typeDeCours": "$(L.typeDeCours)",
				 "nomModule": "$(L.nomModule)",
				 "prof": "$(L.prof)",
				 "salles": "$(L.salles)",
				 "groupe": "$(L.groupe)",
				 "dureeEnMin": $(L.dureeEnMin)},"""
		chJSON *= ch
	end
	# Referme la chaîne de JSON en remplaçant la ',' finale par un ']'
	chJSON = chJSON[1:end-1] * ']'   #TODO: bizarre que ça marche...
	# Retourne la conversion de la chaîne en véritable objet JSON
	return Genie.Renderer.Json.json(chJSON)
end

#= Route permettant d'enregistrer dans une base de données les créneaux créés
   au travers de l'interface web/jquery "planificationSemaine.html"
   L'URL d'appel sera du type :
   http://serveur:8000/insertCreneau?creneau={objet json...}
=#
route("/insertCreneau", method = "GET") do
	creneau = params(:creneau, false)
	if creneau == "?"
		return    # pour précompilation...
	end
	jsonObj = parse(creneau)         # convertit le paramètre en objet JSON
	uuid = jsonObj["uuid"]
	week = Base.parse(Int, jsonObj["week"])
	tab = jsonObj["tab"]
	type = jsonObj["data"]["type"]
	matiere = jsonObj["data"]["matiere"]
	prof = jsonObj["data"]["prof"]
	lieu = jsonObj["data"]["lieu"]
	public = jsonObj["data"]["public"]
	duree = Base.parse(Int, jsonObj["data"]["duree"])
	# Insère le créneau dans la base de données
	insereCreneauBDD(uuid, week, tab, type, matiere, prof, lieu, public, duree,
	                 "", "", "")
	afficheDonnees()
end

#= Route permettant de mettre à jour dans une base de données les créneaux gérés
   au travers de l'interface web/jquery "planificationSemaine.html"
   L'URL d'appel sera du type :
   http://serveur:8000/updateCreneau?creneau={objet json...}
=#
route("/updateCreneau", method = "GET") do
	creneau = params(:creneau, false)
	if creneau == "?"
		return    # pour précompilation...
	end
	jsonObj = parse(creneau)
	uuid = jsonObj["uuid"]
	week = Base.parse(Int, jsonObj["week"])
	tab = jsonObj["tab"]
	type = jsonObj["data"]["type"]
	matiere = jsonObj["data"]["matiere"]
	prof = jsonObj["data"]["prof"]
	lieu = jsonObj["data"]["lieu"]
	public = jsonObj["data"]["public"]
	duree = Base.parse(Int, jsonObj["data"]["duree"])
	# Modifie le créneau connu par son uuid
	updateCreneauBDD(uuid, week, tab, type, matiere, prof, lieu, public, duree,
	                 "", "", "")
	afficheDonnees()
end

#= Route permettant de supprimer de la BDD un créneau spécifié par son uuid
   L'URL d'appel sera du type :
   http://serveur:8000/deleteCreneau?creneau=uuid
=#
route("/deleteCreneau", method = "GET") do
	uuid = params(:creneau, false)
	if uuid == "?"
		return    # pour précompilation...
	end
	supprimeCreneauBDD(uuid)
	afficheDonnees()
end

#= Route permettant de changer l'onglet d'un créneau spécifié par son uuid
   L'URL d'appel sera du type :
   http://serveur:8000/moveCreneau?creneau=uuid&zone=GIM-1A-FI&numSemaine=37
=#
route("/moveCreneau", method = "GET") do
	uuid = params(:creneau, false)
	zone = params(:zone, false)
	numSemaine = params(:numSemaine, false)
	if uuid == "?" || zone == "?" || numSemaine == "?"
		return    # pour précompilation...
	end
	moveCreneauBDD(uuid, zone, Base.parse(Int, numSemaine))
	afficheDonnees()
end

Genie.config.run_as_server = true
# La ligne suivante est nécessaire pour une requête AJAX depuis jquery.
# Info trouvée sur le site :
# https://stackoverflow.com/questions/62166853/how-can-i-setup-cors-headers-in-julia-genie-app-to-allow-post-request-from-diffe
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "http://localhost:8000"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST"
Genie.config.cors_allowed_origins = ["*"]

#= Fonction qui force la "compilation de toutes les routes du serveur. Pour
l'instant génère des erreurs mais ça ne bloque pas le système... A voir. =#
function force_compile()
	println("Lancement de la compilation des routes...")
	#sleep(5)
	#for (name, r) in Router.named_routes()
	  #Genie.Requests.HTTP.request(r.method, "http://localhost:8000" * tolink(name))
	#end
	Genie.Requests.HTTP.request("GET", "http://localhost:8000/constantes")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/lectureDesCreneaux?ressource=?&semaine=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/affecteLesCreneaux?ressource=?&semaine=?&liste=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/selectCreneaux?semaine=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/insertCreneau?creneau=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/updateCreneau?creneau=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/deleteCreneau?creneau=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/moveCreneau?creneau=?&zone=?")
end
  
@async force_compile()
Genie.startup(async = false)     # démarre le serveur web sur le port :8000