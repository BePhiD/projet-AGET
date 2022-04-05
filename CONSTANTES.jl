# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme
# Date Création : Jeudi 13 décembre 2018
# Date Modification : Mardi 18 janvier 2022
# Langage : Julia

# Module : CONSTANTES
# Contient les constantes utiles au projet

using Serialization             # pour relire les données depuis le disque

# Numérotation des semaines de cours sur une année civile (donc 1 à 52)
# Numéros de semaine possibles = futurs indices de tableaux
NBSEMAINES = 52

JOURS = ["Lundi","Mardi","Mercredi","Jeudi","Vendredi"]
NBJOURS = length(JOURS)         # ils seront numérotés de 1:Lundi à 5:Vendredi

# Calcul du nombre de créneaux de 15mn par jour
HEUREDEB,HEUREFIN = 8,19
NBCRENEAUX = 4 * (HEUREFIN - HEUREDEB) - 2   # -2 pour finir à 18h30
MINUTES = ["00","15","30","45"]

SEP = '/'                       # séparateur de fichiers du système

#= Fonction de conversion d'une position numJour,numDeb en jour,horaire
   Exemple : convPosEnJH(2,9) renvoie ("Mardi", "10h00") =#
function convPosEnJH(jour, deb)
    # erreur !    h = Base.div(deb,4) + HEUREDEB
    h = Base.div(deb-1, 4) + HEUREDEB
    m = MINUTES[mod(deb-1,4)+1]
    strHeure = string(h) * "h" * string(m)  # * pour ajouter des strings
    return JOURS[jour], strHeure
end

#= Fonction de conversion d'une position de créneau dans la page web (un nombre
   entre 1 et 210) vers un tuple (jour, deb). Le créneau n°1 est lundi à 8h, le
   n°2 est mardi à 8h, et le n°210 est le vendredi à 18h15. 
   numCreneau est supposé être de type Int =#
function convPosWebEnTupleJourDeb(numCreneau)
    jour = (numCreneau-1) % 5 + 1           # 1 pour lundi, 5 pour vendredi
    debut = Base.div(numCreneau-1, 5) + 1
    return jour, debut
end

#= Fonction de lecture du planning d'une ressource, pour une semaine donnée.
   Renvoie un planning si pas d'erreur, sinon retourne -1 =#
function lecturePlanningDeRessource(ressource, semaine)
   try
      P = deserialize(open(REPERTOIRE_DATA * SEP * ressource * ".dat", "r"))[semaine]
      return P
   catch
      println("Ressource ", ressource, " ou semaine n°", semaine, " non disponible...")
      return -1
   end
end

#= Liste de créneaux interdits (heure de midi et jeudi après-midi)
   définis comme des tuple (jour, deb, nb) avec deb=20-->12h45 et nb=5-->14h =#
CRENEAUX_INTERDITS = [(1,20,5),(2,20,5),(3,20,5),(4,20,5),(5,20,5),   # le midi
                      (4,25,18)             # jeudi après-midi
                     ]

# Répertoires où sont stockées les données du système (.cfg, .dat...)
REPERTOIRE_CFG  = "CONFIG"
REPERTOIRE_DATA = "DATAS"
REPERTOIRE_SEM  = "PLANNINGS"
# Noms des fichiers de configuration des éléments du système
LISTE_PROFS   = "ListeDesProfs.cfg"
LISTE_SALLES  = "ListeDesSalles.cfg"
LISTE_GROUPES = "ListeDesGroupes.cfg"

# Messages d'erreur pour les divers modules
ERR_CR_GROUPE      = "Groupe du créneau inconnu... "
ERR_CR_PROF        = "Prof du créneau inconnu... "
ERR_CR_SALLE       = "Salle du créneau inconnue... "
ERR_CR_DUREE       = "Durée prévue du créneau non multiple de 15mn... "

#
# Zone de constantes pour l'algorithme de Recuit Simulé
#
# Nombre maximal de tours pour la recherche automatique de l'emploi du temps
NBTOURSMAX = 80
# Nombre de tours pour atteindre "l'équilibre thermique"
DUREE_EQUILIBRE_THERMIQUE = 5
# Probabilité initiale de la méthode de recuit simulé (ici 1/2)
PROBA_INITIALE = 0.5
# Pas retiré de la probabilité à chaque tour d'analyse
PAS_PROBA = 0.01
# Minimum de la probabilité possible lors de la phase d'évolution
MIN_PROBA = 0.05
