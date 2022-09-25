#= 
API pour le système de création automatique d'emploi du temps (écrit en julia)
Auteur : Philippe Belhomme (+ Swann Protais pendant son stage de DUT INFO)
Dates de création : lundi 27 décembre 2021
  de modification : samedi 24 septembre 2022
=#

using Genie, Genie.Router, Genie.Renderer.Html, Genie.Requests, Genie.Renderer.Json
import JSON: parse                      # module supplémentaire à installer
include("CONSTANTES.jl")         # pour disposer des constantes de l'application
include("PlanningSemaine.jl")           # pour affecter un créneau dans un x.dat
include("bddPlanificationSemaine.jl")   # pour gérer la base de données
include("Groupes.jl")
include("MoteurRecuitSimule.jl")

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
	# Récupère le nom de la ressource et le numéro de la semaine
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
		# On va connaître l'état du créneau : occupé=false/non occupé=true
		jour, debut = convPosWebEnTupleJourDeb(i)
		D[i] = P[jour, debut]
	end
	return Genie.Renderer.Json.json( Dict("etat" => D) )
end

# Swann/PB : route pour tester si les salles existent dans la BDD SQLite
# l'URL d'appel sera du type :
# http://serveur:8000/checkSalle?nomSalle=C1,C2,AMPHI-C
route("/checkSalle", method = "GET") do
	listeDesSalles = params(:nomSalle, false)
	chJSON = "["
	for salle in split(listeDesSalles, ",")
		reponse = checkExistanceSalle(salle)
		chJSON *= """{"$(salle)": "$(reponse)"},"""
	end
	# Referme la chaîne JSON en remplaçant la ',' finale par un ']'
	chJSON = chJSON[1:end-1] * ']'
	# Retourne la conversion de la chaîne en véritable objet JSON
	return Genie.Renderer.Json.json(chJSON)
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
	liste = params(:liste, false)      # chaine de numéros séparés par une ','
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
	io = open(REPERTOIRE_DATA * SEP * ressource * ".dat", "w")
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
	println("Semaine demandée : $semaine")
	Base.parse(Int, semaine)    # String vers Int
	# Appelle la fonction spécifique du module bddPlanificationSemaine.jl
	df = selectCreneauxBDD(semaine)
	# Place chaque ligne de la BDD dans une chaîne simulant un tableau de JSON
	chJSON = "["
	for ligne in eachrow(df)
		ch = """{"uuid": "$(ligne.uuid)",
		         "tab": "$(ligne.tab)",
				 "typeDeCours": "$(ligne.typeDeCours)",
				 "nomModule": "$(ligne.nomModule)",
				 "prof": "$(ligne.prof)",
				 "salles": "$(ligne.salles)",
				 "groupe": "$(ligne.groupe)",
				 "dureeEnMin": $(ligne.dureeEnMin),
				 "jour": "$(ligne.nomDuJour)",
				 "heure": "$(ligne.horaire)"},"""
		chJSON *= ch
	end
	# Referme la chaîne de JSON en remplaçant la ',' finale par un ']'
	chJSON = chJSON[1:end-1] * ']'
	# Retourne la conversion de la chaîne en véritable objet JSON
	return Genie.Renderer.Json.json(chJSON)
end

# Swann : 
route("/selectPublic", method = "GET") do
	# Appelle la fonction spécifique du module Groupes.jl
	lstGroupes = retourneListeGroupes()
	df1 = DataFrame(groupes = "")
	df2 = DataFrame(groupes = "")
	for e in lstGroupes
		df2 = DataFrame(groupes = e)
		append!(df1, df2)
	end
	# Place chaque ligne de la BDD dans une chaîne simulant un tableau de JSON
	chJSON = "["
	for ligne in eachrow(df1)
		ch = """{"groupes": "$(ligne.groupes)"},"""
		chJSON *= ch
	end
	# Referme la chaîne de JSON en remplaçant la ',' finale par un ']'
	chJSON = chJSON[1:end-1] * ']'
	# Retourne la conversion de la chaîne en véritable objet JSON
	return Genie.Renderer.Json.json(chJSON)
end

#= Swann : action effectuée lorsque l'on clique sur le bouton "lancerMoteur".
   On récupère le numéro de la semaine, le nombre d'emplois du temps que l'on
   souhaite calculer, puis on appelle la fonction "programmePrincipal" qui se
   trouve dans le fichier 'MoteurRecuitSimuke.jl' =#
route("/lancerMoteur", method = "GET") do
	numSemaine = params(:numSemaine, false)
	nbEDTCalcules = params(:nbEDTCalcules, false)
	programmePrincipal(numSemaine, nbEDTCalcules)
end

# Swann : 
route("/selectProf", method = "GET") do
	# Appelle la fonction spécifique du module bddPlanificationSemaine.jl
	df = selectDonneesprof()
	# Place chaque ligne de la BDD dans une chaîne simulant un tableau de JSON
	chJSON = "["
	for ligne in eachrow(df)
		ch = """{"nomProf": "$(ligne.nomProf)"},"""
		chJSON *= ch
	end
	# Referme la chaîne de JSON en remplaçant la ',' finale par un ']'
	chJSON = chJSON[1:end-1] * ']'
	# Retourne la conversion de la chaîne en véritable objet JSON
	return Genie.Renderer.Json.json(chJSON)
end

# Swann : 
route("/ajouterProf", method = "GET") do
	nomProf = params(:nomProf, false)
	# Appelle la fonction spécifique du module bddPlanificationSemaine.jl
	insereProf(nomProf)
end

# Swann : 
route("/supprimerProf", method = "GET") do
	nomProf = params(:nomProf, false)
	# Appelle la fonction spécifique du module bddPlanificationSemaine.jl
	supprimeProf(nomProf)
end

# Swann : 
route("/ajouterSalle", method = "GET") do
	nomSalle = params(:nomSalle, false)
	# Appelle la fonction spécifique du module bddPlanificationSemaine.jl
	insereSalle(nomSalle)
end

# Swann : 
route("/supprimerSalle", method = "GET") do
	nomSalle = params(:nomSalle, false)
	# Appelle la fonction spécifique du module bddPlanificationSemaine.jl
	supprimeSalle(nomSalle)
end

# Swann : 
route("/selectSalles", method = "GET") do
	# Appelle la fonction spécifique du module bddPlanificationSemaine.jl
	df = selectDonneesSalles()
	# Place chaque ligne de la BDD dans une chaîne simulant un tableau de JSON
	chJSON = "["
	for ligne in eachrow(df)
		ch = """{"nomSalle": "$(ligne.nomSalle)"},"""
		chJSON *= ch
	end
	# Referme la chaîne de JSON en remplaçant la ',' finale par un ']'
	chJSON = chJSON[1:end-1] * ']'
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
	#= Insère le créneau dans la base de données (le nom du jour, l'horaire et
	la salle retenue sont forcément vides à ce stade) =#
	insereCreneauBDD(uuid, week, tab, type, matiere, prof, lieu, public, duree,
	                 "", "", "")
	#afficheDonnees()
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
	uuid    = jsonObj["uuid"]
	week    = Base.parse(Int, jsonObj["week"])
	tab     = jsonObj["tab"]
	type    = jsonObj["data"]["type"]
	matiere = jsonObj["data"]["matiere"]
	prof    = jsonObj["data"]["prof"]
	lieu    = jsonObj["data"]["lieu"]
	public  = jsonObj["data"]["public"]
	duree   = Base.parse(Int, jsonObj["data"]["duree"])
	# Modifie le créneau connu par son uuid
	updateCreneauBDD(uuid, week, tab, type, matiere, prof, lieu, public, duree,
	                 "", "", "")
	#afficheDonnees() 
end

# Swann : 
route("/createCSV", method = "GET") do
	numSemaine = params(:numSemaine, false)
	matiere = params(:matiere, false)
	typeCr = params(:typeCr, false)
	duree = params(:duree, false)
	prof = params(:professeur, false)
	salle = params(:salleDeCours, false)
	public = params(:public, false)
	tab = params(:tab, false)
	uuid = params(:uuid, false)
	jour = params(:jour, false)
	heure = params(:heure, false)
	createCSVcreneau(numSemaine, matiere, typeCr, duree, prof, salle, public,
	                 tab, uuid, jour, heure)
end

# Swann : 
route("/deleteAndCreateCSV", method = "GET") do
	numSemaine = params(:numSemaine, false)
	deleteAndCreateCSVcreneau(numSemaine)
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
end

#= Route permettant de déplacer un créneau spécifié par son uuid dans un autre
   onglet. L'URL d'appel sera du type :
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
end

#= Route permettant de forcer un créneau pour le placer à l'avance dans
l'emploi du temps, sans qu'il fasse partie du processus de calcul automatique.
=#
route("/forceCreneau", method = "GET") do
	# Récupère l'id du créneau ainsi que les infos de jour et de début
	numSemaine = Base.parse(Int, params(:numSemaine, 0)) # de String à Int64
	uuid = params(:uuid, false)
	jour = Base.parse(Int, params(:jour, false))
	debCreneau = Base.parse(Int, params(:debCreneau, false))
	prof = params(:prof, false)
	lieu = params(:lieu, false)
	public = params(:public, false)
	duree = Base.parse(Int, params(:duree, false))
	nbQH = Int(duree/15)
	# Convertit les coordonnées numériques en chaînes de caractères
	nomDuJour, heure = convPosEnJH(jour, debCreneau)
    # TODO: Vérifier que prof + groupe + une des salles sont libres
    # Positionne le créneau sur cette position dans la BDD
	updateCreneauForceBDD(uuid, nomDuJour, heure, lieu)
	# Bloque le créneau dans les 3 plannings prof, groupe et salle
	tab_plProf = deserialiseFichierDat(prof)
	tab_plGroupe = deserialiseFichierDat(public)
	tab_plSalle = deserialiseFichierDat(lieu)
	AffecteCreneau(tab_plProf[numSemaine], jour, debCreneau, nbQH)
    AffecteCreneau(tab_plGroupe[numSemaine], jour, debCreneau, nbQH)
    AffecteCreneau(tab_plSalle[numSemaine], jour, debCreneau, nbQH)
	# Ré-enregistre les 3 tableaux de plannings sur le disque dur
	io = open(REPERTOIRE_DATA * SEP * prof * ".dat", "w")
    serialize(io, tab_plProf)
    close(io)
	io = open(REPERTOIRE_DATA * SEP * public * ".dat", "w")
    serialize(io, tab_plGroupe)
    close(io)
	io = open(REPERTOIRE_DATA * SEP * lieu * ".dat", "w")
    serialize(io, tab_plSalle)
    close(io)
end

route("/deForceCreneau", method = "GET") do
	# Récupère l'id du créneau et les infos prof, lieu, public
	uuid = params(:uuid, false)
	prof = params(:prof, false)
	lieu = params(:lieu, false)
	public = params(:public, false)
	duree = Base.parse(Int, params(:duree, false))
	nomDuJour = params(:jour, false)
	heure = params(:heure, false)
	numSemaine = Base.parse(Int, params(:numSemaine, 0)) # de String à Int64
	# Transforme le jour et l'heure en un couple de nombres
	jour, debCreneau = convJHEnPos(nomDuJour, heure)
	nbQH = Int(duree/15)
	# Dépositionne le créneau dans la BDD
	updateCreneauForceBDD(uuid, "", "", "")
	# Débloque le créneau dans les 3 plannings prof, groupe et salle
	tab_plProf = deserialiseFichierDat(prof)
	tab_plGroupe = deserialiseFichierDat(public)
	tab_plSalle = deserialiseFichierDat(lieu)
	LibereCreneau(tab_plProf[numSemaine], jour, debCreneau, nbQH)
    LibereCreneau(tab_plGroupe[numSemaine], jour, debCreneau, nbQH)
    LibereCreneau(tab_plSalle[numSemaine], jour, debCreneau, nbQH)
	# Ré-enregistre les 3 tableaux de plannings sur le disque dur
	io = open(REPERTOIRE_DATA * SEP * prof * ".dat", "w")
    serialize(io, tab_plProf)
    close(io)
	io = open(REPERTOIRE_DATA * SEP * public * ".dat", "w")
    serialize(io, tab_plGroupe)
    close(io)
	io = open(REPERTOIRE_DATA * SEP * lieu * ".dat", "w")
    serialize(io, tab_plSalle)
    close(io)
end

Genie.config.run_as_server = true
# La ligne suivante est nécessaire pour une requête AJAX depuis jquery.
# Info trouvée sur le site :
# https://stackoverflow.com/questions/62166853/how-can-i-setup-cors-headers-in-julia-genie-app-to-allow-post-request-from-diffe
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST"
Genie.config.cors_allowed_origins = ["*"]

#= Fonction qui force la "compilation de toutes les routes du serveur. Pour
l'instant génère des erreurs mais ne bloque pas le système... TODO: à voir. =#
function force_compile()
	println("Lancement de la compilation des routes...")
	Genie.Requests.HTTP.request("GET", "http://localhost:8000/constantes")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/lectureDesCreneaux?ressource=?&semaine=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/affecteLesCreneaux?ressource=?&semaine=?&liste=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/selectCreneaux?semaine=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/insertCreneau?creneau=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/updateCreneau?creneau=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/deleteCreneau?creneau=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/moveCreneau?creneau=?&zone=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/selectProf")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/ajouterProf?nomProf=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/createCSV?numSemaine=?&matiere=?&typeCr=?&duree=?&professeur=?&salleDeCours=?&public=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/deleteAndCreateCSV?numSemaine=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/ajouterSalle?nomSalle=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/selectSalles") 
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/selectPublic")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/checkSalle?nomSalle=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/lancerMoteur?numSemaine=?&nbEDTCalcules=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/supprimerProf?nomProf=?")
	Genie.Requests.HTTP.request("GET", "http://serveur:8000/supprimerSalle?nomSalle=?")
end
  
@async force_compile()
Genie.startup(async = false)     # démarre le serveur web sur le port :8000