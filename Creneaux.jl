# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme
# Date Création : mercredi 23 janvier 2019
# Date Modification : mardi 13 septembre 2022
# Langage : Julia

# Module : Creneaux
# Gestion des créneaux de cours d'un emploi du temps hebdomadaire.
# Les créneaux sont inscrits au départ dans un fichier CSV (issu de ADE ou
# bien d'une interface graphique (HTML5 + CSS3 + JQuery).

include("CONSTANTES.jl")        # pour importer les constantes du système
include("PlanningSemaine.jl")
 

# Définition de la structure Creneau (élément pédagogique à placer dans l'EDT)
mutable struct Creneau
    groupe::String
    prof::String
    salles::Array{String,1}     # tableaux de chaînes de caractères
    nomModule::String           # saisie libre pour plus de souplesse
    typeDeCours::String         # saisie libre pour plus de souplesse
    dureeEnMin::Int             # entier (ex : 90 pour 1h30) multiple de 15
    jour::String                # de la forme : "Lundi, Mardi..."
    horaire::String             # de la forme : "9h30" ou "11h15"
    salleRetenue::String        # salle choisie parmi la liste 'salles'
    numeroDuJour::Int           # numéro du jour 1=Lundi, 5=Vendredi, 6=Samedi
    debutDuCreneau::Int         # numéro du 1/4 d'heure de début (commence à 1)
    nombreDeQuartDHeure::Int    # nombre de quart d'heure occupés
    onglet::String              # onglet (ou tab) auquel appartient le créneau
    uuid::String                # identifiant unique du créneau (36 caractères)
end

# Variables globales du module (disponibles dans ceux qui l'importeront)
ERR_Globales = ""               # par défaut pas d'erreurs

#= Fonction qui analyse la liste des créneaux d'une semaine dont le numéro
    est donné en paramètre. Le fichier analysé sera par exemple 's48.csv'.
    Après la lecture du fichier la validité de chaque créneau est vérifiée.
    Cette fonction renverra la liste des messages d'erreur (vide si ok). =#
function analyseListeDesCreneaux(numSemaine)
    lstCreneaux = []            # liste des créneaux d'une semaine à calculer
    fic = "s" * string(numSemaine) * ".csv"
    LstCr = readlines(open(REPERTOIRE_SEM * SEP * fic, "r"))
    #= Boucle tous les créneaux pour les mettre dans une liste globale.
       ON RESPECTE L'ORDRE DU FICHIER FOURNI PAR LE PRÉVISIONNEL IUT =#
    for e in LstCr
        tabCr = split(e,';')
        groupe    = tabCr[10]
        prof      = tabCr[8]
        salles    = split(tabCr[9], ',')
        salles    = [strip(s) for s in salles]  # retire les espaces en trop
        nomModule = tabCr[3]
        typeCr    = tabCr[4]
        jour      = tabCr[2]
        horaire   = tabCr[6]
        duree     = Base.parse(Int64, string(tabCr[7]))
        salleRetenue = tabCr[9]
        onglet    = tabCr[11]
        uuid      = tabCr[12]
        # Crée une instance d'objet de la structure Creneau (par défaut valide)
        c = Creneau(groupe, prof, salles, nomModule, typeCr, duree,
                    jour, horaire, salleRetenue, 0, 0, 0, onglet, uuid)
        #= Stocke ces créneaux dans une liste qui deviendra la 'corbeille' du
           futur calcul automatique de l'emploi du temps. =#
        push!(lstCreneaux,c)
    end
    # Démarrage de la vérification des créneaux contenus dans 'lstCreneaux'
    verifieValiditeDesCreneaux(lstCreneaux)
    return lstCreneaux
end

# Génère un fichier ".dat" (pour l'année) d'un prof ou d'une salle
function creeFichierDatPourProfOuSalle(identifiant, message)
    P = []                          # tableau vide (contiendra 52 plannings)
    for x in 1:NBSEMAINES  push!(P, PlanningSemaine())  end
    io = open(REPERTOIRE_DATA * SEP * identifiant * ".dat", "w")
    serialize(io, P)
    close(io)
    println(message, identifiant, "... OK")
end

#= Fonction qui vérifie tous les créneaux qui vont être placés (ou non...) par
   le moteur de calcul automatique de l'emploi du temps et qui s'assure qu'ils
   sont bien associés à un fichier .dat =#
function verifieValiditeDesCreneaux(lstCreneaux)
    fichiersPresents = readdir(REPERTOIRE_DATA)
    # Passe tous les noms de fichiers en minuscule pour être tranquille
    for i in eachindex(fichiersPresents)
        fichiersPresents[i] = lowercase(fichiersPresents[i])
    end
    include("Groupes.jl")           # construit la hiérarchie des groupes
    numC = 1                        # numéro du créneau en cours d'examen
    for c in lstCreneaux
        erreur = ""                 # vide par défaut
        # Vérifie le prof
        if !(lowercase(c.prof) * ".dat" in fichiersPresents)
            # Crée le .dat du prof puisqu'il n'est pas connu
            creeFichierDatPourProfOuSalle(c.prof, "Création du prof : ")
            push!(fichiersPresents, lowercase(c.prof) * ".dat")
            insereProfdepuisMoteur(c.prof)   # ne devrait plus arriver...
        end
        # Vérifie la ou les salles
        for salle in c.salles
            if !(lowercase(salle) * ".dat" in fichiersPresents)
                # Crée le .dat de la salle puisqu'elle n'est pas connue
                creeFichierDatPourProfOuSalle(uppercase(salle), "Création de la salle : ")
                push!(fichiersPresents, lowercase(salle) * ".dat")
            end
        end
        # Vérifie la durée
        if c.dureeEnMin % 15 != 0
            erreur *= "\t" * ERR_CR_DUREE * string(c.dureeEnMin) * "\n"
        end
        # Vérifie le groupe
        if !(c.groupe in keys(hierarchieGroupes))
            erreur *= "\t" * ERR_CR_GROUPE * c.groupe * "\n"
        end
        # MAJ du message des erreurs globales si le créneau présente une erreur
        if erreur != ""
            global ERR_Globales *= "[" * string(numC) * "]" * erreur
        end
        numC += 1                   # incrémente le numéro de créneau en cours
    end
    if ERR_Globales != "" println(ERR_Globales) end
end

### PROGRAMME PRINCIPAL
#r = analyseListeDesCreneaux(48) ; println(r)
