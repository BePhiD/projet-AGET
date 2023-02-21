# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme
# Date Création : Jeudi 13 décembre 2018
# Date Modification : Mardi 21 février 2023
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
    h = Base.div(deb-1, 4) + HEUREDEB
    m = MINUTES[mod(deb-1,4)+1]
    strHeure = string(h) * "h" * string(m)  # * pour ajouter des strings
    return JOURS[jour], strHeure
end

#= Fonction de conversion d'une position jour,horaire en numJour,numDeb
   Exemple : convJHEnPos("Mardi", "10h00") renvoie (2,9) =#
   function convJHEnPos(jourEnLettres, horaire)
      h = Base.parse(Int64, split(horaire, 'h')[1])
      m = split(horaire, 'h')[2]
      m = findall(x -> x == m, MINUTES)[1]
      deb = (h-8)*4 + m
      jourEnChiffre = findall(x -> x == jourEnLettres, JOURS)[1]
      return jourEnChiffre, deb
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
   définis comme des tuples (jour, deb, nb) avec deb=20-->12h45 et nb=5-->14h =#
CRENEAUX_INTERDITS = [(1,20,5),(2,20,5),(3,20,5),(4,20,5),(5,20,5),   # le midi
                      (4,25,18)             # jeudi après-midi
                     ]
#= Liste de jours fériés définis comme des tuples :
   (numSemaine, numJour, commentaire).
   numJour vaut 1 pour Lundi et 5 pour Vendredi =#*
JOURS_FERIES = [(44, 2, "Mardi 1er nov 2022 ; Toussaint"),
                (45, 5, "Vendredi 11 nov 2022 ; Armistice 1918"),
                (15, 1, "Lundi 10 avril 2023 ; Lundi de Pâques"),
                (18, 1, "Lundi 1er mai 2023 ; Fête du travail"),
                (19, 1, "Lundi 8 mai 2023 ; Armistice 1945"),
                (20, 4, "Jeudi 18 mai 2023 ; Jeudi de l'Ascension"),
                (22, 1, "Lundi 29 mai 2023 ; Lundi de Pentecôte")]

# Répertoires où sont stockées les données du système (.cfg, .dat...)
REPERTOIRE_CFG   = "CONFIG"
REPERTOIRE_DATA  = "DATAS"
REPERTOIRE_SEM   = "PLANNINGS"
REPERTOIRE_PLAN  = "PLANNINGS_CALCULES"
# Noms des fichiers de configuration des éléments du système
LISTE_PROFS   = "ListeDesProfs.cfg"
LISTE_SALLES  = "ListeDesSalles.cfg"
LISTE_GROUPES = "ListeDesGroupes.cfg"

# Nom de la base de données SQLite gérant tout le système
NOM_DATABASE_EDT = "bddAutomaticEDT.sql"

# Nom du fichier indiquant le classement des plannings calculés
NOM_FICHIER_CLASSEMENT = "classement.txt"

# Messages d'erreur pour les divers modules
ERR_CR_GROUPE      = "Groupe du créneau inconnu... "
ERR_CR_PROF        = "Prof du créneau inconnu... "
ERR_CR_SALLE       = "Salle du créneau inconnue... "
ERR_CR_DUREE       = "Durée prévue du créneau non multiple de 15mn... "

#
# Zone de constantes pour l'algorithme de Recuit Simulé
#
# Nombre maximal de tours pour atteindre "l'équilibre thermique"
DUREE_EQUILIBRE_THERMIQUE = 100
# Nombre de tentatives réussies pour quitter l'équilibre thermique
NB_TENTATIVES_REUSSIES = 12
# Maximum de tours sans changement d'EDT autorisé
NB_MAX_DE_TOURS_SC = 3
# A chaque tour la température du système baisse (ici de 10%)
COEFF_DECROISSANCE_DE_T = 0.9
# Température initiale de la méthode de recuit simulé
#τ0 = 0.5       # 50% si on pense qu'au départ la disposition n'est pas terrible
τ0 = 0.33      # 33% si on pense qu'au départ la disposition n'est pas trop mal
# Valeurs d'énergie moyenne constatée selon la méthode utilisée pour le calcul
# de la différence d'énergie d'un créneau avant/après placement
DictΔEmoyen = Dict("PAR_JOUR" => 90,
                   "PAR_TRANCHE" => 107,
                   "PAR_EXPONENTIELLE" => 78)
METHODE_ΔE = "PAR_EXPONENTIELLE"
ΔEmoyen = DictΔEmoyen[METHODE_ΔE]
T0 = -ΔEmoyen / (log(τ0))
# Paramètres α et β pour la méthode "PAR_EXPONENTIELLE"
# Dans cette méthode : lundi->0  vendredi->100  8h->0   17h->100
α = 0.92602
β = 0.276015
# Valeur de la probabilité de "secouage" au départ
MAX_PROBA = τ0
# Minimum de la probabilité possible lors de la phase de "secouage"
MIN_PROBA = 0.05
# Pas de décroissance de la probabilité de "secouage"
PAS_PROBA = 0.01
