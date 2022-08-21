# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme (+ Swann Protais pendant son stage de DUT INFO)
# Date Création : jeudi 21 février 2019
# Date Modification : samedi 20 août 2022 (correction stratégie calcul !)
# Langage : Julia

# Module : MoteurRecuitSimule
# Pour calculer AUTOMATIQUEMENT l'emploi du temps d'une semaine donnée

include("CONSTANTES.jl")        # pour importer les constantes du système
include("bddPlanificationSemaine.jl")
include("Creneaux.jl")          # pour charger la liste des créneaux à traiter
include("Groupes.jl")           # pour charger la hiérarchie des groupes
using Serialization             # pour relire les données depuis le disque
using Random                    # pour la fonction shuffle!
using DataFrames
using CSV

### Structure du moteur contenant tous les éléments pour calculer l'EDT
mutable struct Moteur
    info::String                # description du moteur
    numSemaine::Int             # numéro de la semaine à construire  
    dctP                        # dictionnaire des Profs
    dctG                        # dictionnaire des Groupes
    dctS                        # dictionnaire des Salles
    collCreneauxNP              # collection des créneaux Non Placés
    collCreneauxP               # collection des créneaux Placés
    probabilite::Float32        # probabilité du moteur de recuit simulé
    nbreTours::Int              # nombre de "tours de recuit simulé"
    nbCreneaux::Int             # somme des 2 collections en fait
    rendement::Float32          # rendement de placement de ce moteur
end

#= Prépare tous les éléments nécessaires au traitement d'une semaine.
Par défaut la collection de créneaux à placer est vide. Le moteur ne pourra
tourner que si le moteur est 'alimenté' en créneaux à traiter. =#
function prepareMoteur(numSemaine)
    M = Moteur("", numSemaine, Dict(),Dict(),Dict(), [],[],
               PROBA_INITIALE, 0, 0, 0.0)
    M.info = "Je suis le moteur qui bosse sur la semaine $numSemaine..."
    lstCreneaux = analyseListeDesCreneaux(numSemaine)
    if ERR_Globales != ""       # vient du module 'Creneaux.jl'
        M.info = "Erreur !!!" * ERR_Globales
    else
        M.collCreneauxNP = lstCreneaux
        M.nbCreneaux = length(M.collCreneauxNP)
        chargeLesProfs(M)
        chargeLesSalles(M)
        chargeLesGroupes(M)     # avec les parents/enfants
    end
    return M
end

### Permet de relire depuis le disque dur un fichier .dat sérialisé auparavant
function deserialiseFichierDat(fic)
    return deserialize(open(REPERTOIRE_DATA * SEP * fic * ".dat", "r"))
end

### Charge le planning de la semaine traitée pour chaque prof
function chargeLesProfs(M)
    for cr in M.collCreneauxNP
        if !(cr.prof in keys(M.dctP))
            M.dctP[cr.prof] = deserialiseFichierDat(cr.prof)[M.numSemaine]
        end
    end
end

### Charge le planning de la semaine traitée pour chaque salle
function chargeLesSalles(M)
    for cr in M.collCreneauxNP
        for salle in cr.salles
            if !(salle in keys(M.dctS))
                M.dctS[salle] = deserialiseFichierDat(salle)[M.numSemaine]
            end
        end
    end
end

### Charge le planning de la semaine traitée pour chaque groupe
function chargeLesGroupes(M)
    # Charge d'abord les groupes directement concernés par un créneau à placer
    for cr in M.collCreneauxNP
        if !(cr.groupe in keys(M.dctG))
            M.dctG[cr.groupe] = deserialiseFichierDat(cr.groupe)[M.numSemaine]
        end
    end
    # Puis ajoute les 'père & fils' de chaque groupe tant que nécessaire
    onContinue = true
    while onContinue
        onContinue = false                # baisse le drapeau...
        for grp in keys(M.dctG)
            famille = append!(copy(hierarchieGroupes[grp].pere),
                                   hierarchieGroupes[grp].fils)
            for f in famille
                if !(f in keys(M.dctG))
                    M.dctG[f] = deserialiseFichierDat(f)[M.numSemaine]
                    onContinue = true     # lève le drapeau !
                end
            end
        end
    end
end

### Cherche à positionner dans l'EDT les créneaux non encore placés du moteur
function positionneLesCreneauxNonPlaces(M)
    for tour in 1:length(M.collCreneauxNP)       # tour sera un entier
        cr = popfirst!(M.collCreneauxNP)         # retire un créneau de la pile
        nbQH = Int(cr.dureeEnMin / 15)           # nombre de quarts d'heure
        # Obtenir le planning du prof concerné par le créneau
        plProf = M.dctP[cr.prof]                 # planning du prof (alias)
        #= Construire l'intersection du planning du groupe et de tous ses
           PERES/FILS, donc le planning de sa 'FAMILLE' complète. =#
        plGroupe = M.dctG[cr.groupe]             # planning du groupe (alias)
        plFamille = PlanningSemaine(true)        # planning ENTIEREMENT vide
        plFamille = Intersection(plFamille, plGroupe)
        for e in rechercheFamilleDuGroupe(cr.groupe)
            plFamille = Intersection(plFamille, M.dctG[e])
        end
        #= Regarder déjà si le prof et le groupe peuvent coincider =#
        plProfGroupe = Intersection(plProf, plFamille)
        jour, debut = ouEstCePossible(nbQH, plProfGroupe) # tuple (j,d) ou (0,0)
        if jour != 0                             # ce serait possible...
            # Chercher si l'une des salles est disponible (priorité = ordre)
            # Par défaut, cr.salleRetenue == ""
            for salle in cr.salles               # balaye toutes les salles
                #= Construction du planning mixant toutes les entités ; c'est
                   donc celui dans lequel on cherchera une place possible au
                   créneau (prof + groupe + salle).
                   bas -> 'bac à sable'
                =#
                plSalle = M.dctS[salle]
                bas = Intersection(plProfGroupe, plSalle)
                jourFinal, debutFinal = ouEstCePossible(nbQH, bas)
                if jourFinal != 0                # on a trouvé !
                    cr.salleRetenue = salle      # retient la salle utilisée
                    # On stocke les informations de position/taille du créneau
                    cr.numeroDuJour = jourFinal
                    cr.debutDuCreneau = debutFinal
                    cr.nombreDeQuartDHeure = nbQH
                    #= Convertit la position en quelque chose de lisible.
                       Ainsi : convPosEnJH(2,9) renvoit ("Mardi", "10h00") =#
                    cr.jour, cr.horaire = convPosEnJH(jourFinal, debutFinal)
                    # On peut maintenant fixer le créneau dans les 3 plannings
                    AffecteCreneau(plProf, jourFinal, debutFinal, nbQH)
                    AffecteCreneau(plGroupe, jourFinal, debutFinal, nbQH)
                    AffecteCreneau(plSalle, jourFinal, debutFinal, nbQH)
                    # Le créneau peut maintenant partir dans la liste des Placés
                    push!(M.collCreneauxP, cr)
                    break                        # quitte le for car salle ok
                end
            end
            #= Ici, à la fin de la boucle for, si la salle retenue est vide
               c'est qu'aucune salle n'était disponible. Le créneau doit alors
               retourner dans la liste des NonPlacés.
            =#
            if cr.salleRetenue == ""
                push!(M.collCreneauxNP, cr)      # cr retourne dans la pile NP
            end
        else  # inutile d'aller plus loin, le prof et le groupe ne matchent pas
            push!(M.collCreneauxNP, cr)          # cr retourne dans la pile NP
        end
    end
end

# Retire de l'EDT des créneaux déjà placés (recuit : utilise la proba du moteur)
function retireDesCreneauxSelonUneProbabilite(M)
    shuffle!(M.collCreneauxP)             # mélange sur place la collection
    for tour in 1:length(M.collCreneauxP)
        if rand() < M.probabilite
            cr = popfirst!(M.collCreneauxP)
            j,d,n = cr.numeroDuJour, cr.debutDuCreneau, cr.nombreDeQuartDHeure
            LibereCreneau(M.dctP[cr.prof],j,d,n)            # libère le prof
            LibereCreneau(M.dctS[cr.salleRetenue],j,d,n)    # libère la salle
            LibereCreneau(M.dctG[cr.groupe],j,d,n)          # libère le groupe
            # Nettoie l'horaire du créneau ainsi que la salle retenue
            cr.numeroDuJour = cr.debutDuCreneau = 0
            cr.jour = cr.horaire = cr.salleRetenue = ""
            # et enfin le remet dans la liste des Non-Placés
            push!(M.collCreneauxNP, cr)
        end
    end
end

### La probabilité baisse à chaque tour en conservant une limite inférieure
function faitEvoluerLaProbabilite(moteur)
    moteur.probabilite = max(moteur.probabilite - PAS_PROBA, MIN_PROBA)
end

### Fonction qui va réellement calculer l'EDT d'une semaine ; reçoit un 'moteur'
function runMoteur(M)
    M.nbreTours = 1                       # numéro du tour actuel
    while M.nbreTours < NBTOURSMAX && length(M.collCreneauxNP) > 0
        shuffle!(M.collCreneauxNP)        # mélange sur place la collection NP
        #TODO: ce serait bien de les trier par ordre de 'places possibles'
        for t in 1:DUREE_EQUILIBRE_THERMIQUE
            positionneLesCreneauxNonPlaces(M)
            if length(M.collCreneauxNP)>0 # s'il reste des créneaux à placer
                retireDesCreneauxSelonUneProbabilite(M)
            else
                break                     # sort de la boucle for (puis while)
            end
        end
        faitEvoluerLaProbabilite(M)
        M.nbreTours += 1                  # MAJ du numéro de tour
    end
    # Inscrit les 'performances' du moteur dans sa propre structure
    nbCrBienPlaces = length(M.collCreneauxP)
    M.rendement = round(10000 * nbCrBienPlaces / M.nbCreneaux) / 100
end

### Fonction qui affiche l'emploi du temps calculé et l'enregistre dans un CSV
function afficheEnregistreEDT(M, numSemaine, tour)
    # Crée un fichier par tour, sur le modèle : s39_1.csv, s39_2.csv, etc.
    nom = REPERTOIRE_PLAN * SEP * string(numSemaine) * SEP
    nom *= "s" * string(numSemaine) * "_" * string(tour) * ".csv"
    touch(nom)
    println("[++++]Créneaux placés...")
    for e in M.collCreneauxP
        println(e)
        # Remplit le CSV avec les créneaux placés (donc avec la salle retenue)
        df = DataFrame(semaine = [numSemaine], JourduCours = [e.jour],
                       matiere = [e.nomModule], typeCr = [e.typeDeCours],
                       numApogee = "numApogee", heure = [e.horaire],
                       duree = [e.dureeEnMin], professeur = [e.prof],
                       salleDeCours = [e.salleRetenue], public = [e.groupe])
        CSV.write(nom, df, header = false, append = true, delim=';')
    end
    println("[----]Créneaux NON placés...")
    for e in M.collCreneauxNP  
        println(e)  
        # Remplit le CSV avec les créneaux non-placés (donc avec les salles)
        df = DataFrame(semaine = [numSemaine], JourduCours = [e.jour],
                       matiere = [e.nomModule], typeCr = [e.typeDeCours],
                       numApogee = "numApogee", heure = [e.horaire],
                       duree = [e.dureeEnMin], professeur = [e.prof],
                       salleDeCours = [e.salles], public = [e.groupe])
        CSV.write(nom, df, header = false, append = true, delim=';')
    end
    strStat = " (" * string(length(M.collCreneauxP)) * "/" 
    strStat *= string(M.nbCreneaux) * ")"
    println("Rendement : ", M.rendement, " %  ", strStat)
    println("Tout ça en ", M.nbreTours, " tours de recuit simulé !") 
end

#######################
### PROGRAMME PRINCIPAL
#######################
function programmePrincipal(semaine, nbEDTCalcules)
	semaine = Base.parse(Int64, semaine)
	nbEDTCalcules = Base.parse(Int64, nbEDTCalcules)
    # Supprime si possible le dossier qui contiendra les plannings de la semaine
    rm(REPERTOIRE_PLAN * SEP * string(semaine), force=true, recursive=true)
    # Recrée le dossier (il est donc vide)
    mkdir(REPERTOIRE_PLAN * SEP * string(semaine))
	for tour in 1:nbEDTCalcules
	    println("*** Tour n°", tour, "/", nbEDTCalcules, " ***")
	    moteur = prepareMoteur(semaine)
	    runMoteur(moteur)
	    afficheEnregistreEDT(moteur, semaine, tour)
	end
end
