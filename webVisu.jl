#= 
Visu pour le système de création automatique d'emploi du temps (écrit en julia)
Auteur : Philippe Belhomme
Dates de création : vendredi 26 août 2022
  de modification : dimanche 09 juillet 2023

Ce programme est appelé avec la commande suivante :
julia webVisu.jl numSemaine numPlanning promo
exemple : julia webVisu.jl 36 1 GIM-2A-FI
=#

# Mettre tous les caractères en MAJUSCULE dans les groupes !!!
GROUPES = """{
  "GIM-2A-FI": {"pos": 1, "taille": 1},
  "TD-GIM-2A-FI": {"pos": 1, "taille": 1},
  "TP-GIM-2A-FI": {"pos": 1, "taille": 1},

  "GIM-2A-APP": {"pos": 1, "taille": 2},
  "TD-GIM-2A-APP": {"pos": 1, "taille": 2},
  "TP1-GIM-2A-APP": {"pos": 1, "taille": 1},
  "TP2-GIM-2A-APP": {"pos": 2, "taille": 1},

  "GIM-1A-FI": {"pos": 1, "taille": 2},
  "TD-GIM-1A-FI": {"pos": 1, "taille": 2},
  "TP1-GIM-1A-FI": {"pos": 1, "taille": 1},
  "TP2-GIM-1A-FI": {"pos": 2, "taille": 1},

  "GIM-1A-APP": {"pos": 1, "taille": 2},
  "TD-GIM-1A-APP": {"pos": 1, "taille": 2},
  "TP1-GIM-1A-APP": {"pos": 1, "taille": 1},
  "TP2-GIM-1A-APP": {"pos": 2, "taille": 1},


  "GEII-S1-S2": {"pos": 1, "taille": 6},
  "G12-GEII-S1-S2": {"pos": 1, "taille": 6},
  "G1-GEII-S1-S2": {"pos": 1, "taille": 3},
  "G2-GEII-S1-S2": {"pos": 4, "taille": 3},
  "G1A-GEII-S1-S2": {"pos": 1, "taille": 2},
  "G1B2A-GEII-S1-S2": {"pos": 3, "taille": 2},
  "G2B-GEII-S1-S2": {"pos": 5, "taille": 2},

  "GEII-S3-S4": {"pos": 1, "taille": 6},
  "G12-GEII-S3-S4": {"pos": 1, "taille": 6},
  "G1-GEII-S3-S4": {"pos": 1, "taille": 3},
  "G2-GEII-S3-S4": {"pos": 4, "taille": 3},
  "G1A-GEII-S3-S4": {"pos": 1, "taille": 2},
  "G1B2A-GEII-S3-S4": {"pos": 3, "taille": 2},
  "G2B-GEII-S3-S4": {"pos": 5, "taille": 2},

  "GEII-S5-S6": {"pos": 1, "taille": 6},
  "G12-GEII-S5-S6": {"pos": 1, "taille": 6},
  "G1-GEII-S5-S6": {"pos": 1, "taille": 3},
  "G2-GEII-S5-S6": {"pos": 4, "taille": 3},
  "G1A-GEII-S5-S6": {"pos": 1, "taille": 2},
  "G1B2A-GEII-S5-S6": {"pos": 3, "taille": 2},
  "G2B-GEII-S5-S6": {"pos": 5, "taille": 2},

  "GEIIALT-S1-S2": {"pos": 1, "taille": 2},
  "GEII-GEIIALT-S1-S2": {"pos": 1, "taille": 2},
  "GEII1-GEIIALT-S1-S2": {"pos": 1, "taille": 1},
  "GEII2-GEIIALT-S1-S2": {"pos": 2, "taille": 1},

  "GEIIALT-S3-S4": {"pos": 1, "taille": 2},
  "GEII-GEIIALT-S3-S4": {"pos": 1, "taille": 2},
  "GEII1-GEIIALT-S3-S4": {"pos": 1, "taille": 1},
  "GEII2-GEIIALT-S3-S4": {"pos": 2, "taille": 1}
}"""

using Gtk
using JSON
include("CONSTANTES.jl")        # pour importer les constantes du système

JSON_G = JSON.parse(GROUPES)

function afficheLesHeuresDansLaGrille()
  pos = 2
  # Affichage des heures en colonne 1, un label par quart d'heure
  for heure in HEUREDEB:HEUREFIN-1
    for q = 1:4
      b = GtkLabel(string(heure) * "h" * MINUTES[q])
      grille[1, pos] = b
      pos += 1
    end
  end
end

function afficheLesJoursDansLaGrille(n)
  # Affichage du numJour en ligne 1, sur n colonnes
  for j = 1:length(JOURS)
    b = GtkButton(JOURS[j])
    c = 2 + (j-1)*n
    grille[c : c+n-1, 1] = b
  end
end

function litUnPlanningSemainePourUnePromo(semaine, numPlanning, onglet)
  # Lit la totalité du fichier "EDT calculé"
  fic = "s" * string(semaine) * "_" * string(numPlanning) * ".csv"
  LstCr = readlines(open(REPERTOIRE_PLAN * SEP * string(semaine) * SEP * fic, "r"))
  # Décompose chaque ligne en un "créneau" ; commence à 2 car ligne d'en-tête
  for i in 2:length(LstCr)
    tabCr = split(LstCr[i],';')
    promo = tabCr[1]
    # Passe au suivant si le créneau n'appartient pas à l'onglet voulu
    if promo != onglet continue end
    jourEnLettres = tabCr[2]
    # Passe au suivant si le créneau n'a pas été affecté quelque part
    if jourEnLettres == "" continue end
    matiere = tabCr[5]
    type = tabCr[4]
    heure = tabCr[3]
    dureeEnMin = string(tabCr[7])
    prof = tabCr[6]
    salle = tabCr[9]
    groupe = tabCr[10]
    # Convertit l'information "jour/horaire" en numJour/num Creneau de début
    numJour, deb = convJHEnPos(jourEnLettres, heure)
    # Obtient le nombre de quarts d'heure couverts par le créneau
    dureeEnQH = Int(Base.parse(Int64, dureeEnMin)/15)
    # Crée un widget "button" pour afficher le créneau
    b = GtkButton(type * " " * matiere * "\n" * prof * "\n" * salle)
    # Positionne le créneau à la bonne place dans la grille selon le groupe
    x, y, Δx, Δy = posEtTailleCreneau(promo, groupe, numJour, deb, dureeEnQH)
    grille[x:x+Δx, y:y+Δy] = b
  end
end

function posEtTailleCreneau(promo, groupe, numJour, deb, dureeEnQH)
  x = (numJour-1) * JSON_G[promo]["taille"] + JSON_G[groupe]["pos"] + 1
  Δx = JSON_G[groupe]["taille"] - 1
  return x, deb+1, Δx, dureeEnQH-1     # x, y, Δx, Δy
end

# Création de la fenêtre principale et de sa grille
ns = ARGS[1]          # numéro de semaine
np = ARGS[2]          # numéro de planning
formation = ARGS[3]   # nom de l'onglet (donc promo) dans webAPI.jl
win = GtkWindow("-- SEMAINE $ns -- Planning n°$np pour $formation")
grille = GtkGrid()
set_gtk_property!(grille, :column_homogeneous, true)
set_gtk_property!(grille, :column_spacing, 4)  # gap in pixels between columns

# Préparation de la structure de base de l'affichage
afficheLesHeuresDansLaGrille()
largeurColonne = JSON_G[ARGS[3]]["taille"]   # taille du 'père' (= nom onglet)
afficheLesJoursDansLaGrille(largeurColonne)
# Appel du pgm : julia webVisu.jl numSemaine numPlanning promo
# donc on peut extraire les informations utiles pour afficher les créneaux
litUnPlanningSemainePourUnePromo(ARGS[1], ARGS[2], ARGS[3])

push!(win, grille)
showall(win)

#= Code nécessaire pour que la fenêtre ne se referme pas aussitôt après la
commande : showall(win)  =#
if !isinteractive()
    c = Condition()
    signal_connect(win, :destroy) do widget
        notify(c)
    end
    @async Gtk.gtk_main()
    wait(c)
end
