# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme
# Date Création : Jeudi 21 février 2019
# Date Modification : Vendredi 24 mai 2019
# Langage : Julia

# Module : MoteurRecuitSimule
# Pour calculer AUTOMATIQUEMENT l'emploi du temps d'une semaine donnée

include("CONSTANTES.jl")        # pour importer les constantes du système
include("Creneaux.jl")          # pour charger la liste des créneaux à traiter
include("Groupes.jl")           # pour charger la hiérarchie des groupes
using Serialization             # pour relire les données depuis le disque
using Random                    # pour la fonction shuffle!

# Structure du moteur contenant tous les éléments pour calculer l'EDT
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

#= Prépare tous les élements nécessaires au traitement d'une semaine.
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
        chargeLesGroupes(M)               # avec les parents/enfants
    end
    return M
end

function deserialiseFichierDat(fic)
    return deserialize(open(REPERTOIRE_DATA * SEP * fic * ".dat", "r"))
end

# Charge le planning de la semaine traitée pour chaque prof
function chargeLesProfs(M)
    for cr in M.collCreneauxNP
        if !(cr.prof in keys(M.dctP))
            M.dctP[cr.prof] = deserialiseFichierDat(cr.prof)[M.numSemaine]
        end
    end
end

# Charge le planning de la semaine traitée pour chaque salle
function chargeLesSalles(M)
    for cr in M.collCreneauxNP
        for salle in cr.salles
            if !(salle in keys(M.dctS))
                M.dctS[salle] = deserialiseFichierDat(salle)[M.numSemaine]
            end
        end
    end
end

# Charge le planning de la semaine traitée pour chaque groupe
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
                    M.dctG[f] = deserialiseFichierDat(f)
                    onContinue = true     # lève le drapeau !
                end
            end
        end
    end
end

# Cherche à placer dans l'EDT les créneaux non placés du moteur
function positionneLesCreneauxNonPlaces(M)
    for tour in 1:length(M.collCreneauxNP)
        cr = popfirst!(M.collCreneauxNP)        # retire le créneau de la pile
        nbQH = Int(cr.dureeEnMin / 15)          # nombre de quarts d'heure
        for salle in cr.salles                  # balaye toutes les salles
            j,d = ouEstCePossible(nbQH,M.dctS[salle]) # tuple (j,d) ou (0,0)
            if j != 0
                cr.salleRetenue = salle         # retient la salle utilisée
                break                           # quitte le for...
            end
        end
        if cr.salleRetenue == ""                # pas de salle disponible...
            push!(M.collCreneauxNP, cr)         # cr retourne dans la pile NP
            continue                            # passe au tour suivant
        end
        ### Ici on a forcément trouvé une salle possible
        plProf   = M.dctP[cr.prof]              # planning du prof (alias)
        plGroupe = M.dctG[cr.groupe]            # planning du groupe (alias)
        plSalle  = M.dctS[cr.salleRetenue]      # planning de la salle (alias)
        # Planning 'bac à sable' pour fusionner ceux des entités du créneau
        bas = PlanningSemaine()
        #= Construction du planning mixant toutes les entités ; c'est donc
           celui dans lequel on cherchera une place au créneau =#
        bas = Intersection(bas, plProf, plGroupe, plSalle)
        jour,debut = ouEstCePossible(nbQH, bas) # tuple (j,d) ou (0,0)
        if jour != 0                            # on a trouvé une place !
            # On stocke les informations (jour,deb,nbQH)
            cr.numeroDuJour = jour
            cr.debutDuCreneau = debut
            cr.nombreDeQuartDHeure = nbQH
            # Convertit la position en quelque chose de lisible
            # Exemple : convPosEnJH(2,9) renvoit ("Mardi", "10h00")
            cr.jour,cr.horaire = convPosEnJH(jour,debut)
            # on peut placer le créneau dans le planning...
            AffecteCreneau(plProf, jour, debut, nbQH)     # ... du prof
            AffecteCreneau(plSalle, jour, debut, nbQH)    # ... de la salle
            AffecteCreneau(plGroupe, jour, debut, nbQH)   # ... du groupe
            # ... et DES PERE/FILS EN CASCADE, donc sa 'famille'
            Fam = rechercheFamilleDuGroupe(cr.groupe)
            for e in Fam  AffecteCreneau(M.dctG[e], jour, debut, nbQH)  end
            # Le créneau peut maintenant partir dans la liste des Placés
            push!(M.collCreneauxP, cr)
        else
            push!(M.collCreneauxNP, cr)         # cr retourne dans la pile NP
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
            # Libére les plannings des ascendants/descendants
            famille = rechercheFamilleDuGroupe(cr.groupe)
            for e in famille  LibereCreneau(M.dctG[e],j,d,n)  end
            # Nettoie l'horaire du créneau ainsi que la salle retenue
            cr.numeroDuJour = cr.debutDuCreneau = 0
            cr.jour = cr.horaire = cr.salleRetenue = ""
            # et enfin le remet dans la liste des Non-Placés
            push!(M.collCreneauxNP, cr)
        end
    end
end

# La probabilité baisse à chaque tour en conservant une limite inférieure
function faitEvoluerLaProbabilite(moteur)
    moteur.probabilite = max(moteur.probabilite - PAS_PROBA, MIN_PROBA)
end

# Fonction qui va réellement calculer l'EDT d'une semaine ; reçoit un 'moteur'
function runMoteur(M)
    #println(M.info)
    M.nbreTours = 1                       # numéro du tour actuel
    while M.nbreTours < NBTOURSMAX && length(M.collCreneauxNP) > 0
        shuffle!(M.collCreneauxNP)        # mélange sur place la collection NP
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

# Fonction qui affiche l'emploi du temps calculé
#TODO: devra modifier le fichier original
function afficheEDT(M)
    println("[++++]Créneaux placés...")
    for e in M.collCreneauxP   println(e)  end
    println("[----]Créneaux NON placés...")
    for e in M.collCreneauxNP  println(e)  end
    strStat = " (" * string(length(M.collCreneauxP)) * "/"
    strStat *= string(M.nbCreneaux) * ")"
    println("Rendement : ", M.rendement, " %  ", strStat)
    println("Tout ça en ", M.nbreTours, " tours de recuit simulé !")
end

### PROGRAMME PRINCIPAL
numSemaine = parse(Int, ARGS[1])          # lit la ligne de commande
nbEDTCalcules = 1
try
    global nbEDTCalcules = parse(Int, ARGS[2])  # global sinon interne au try
catch
    println("Par défaut calcul d'un seul emploi du temps.")
end
for tour in 1:nbEDTCalcules
    println("*** Tour n°", tour, "/", nbEDTCalcules, " ***")
    moteur = prepareMoteur(numSemaine)
    runMoteur(moteur)
    afficheEDT(moteur)
end
