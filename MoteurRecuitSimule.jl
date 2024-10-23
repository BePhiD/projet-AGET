# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme (+ Swann Protais pendant son stage de DUT INFO)
# Date Création : jeudi 21 février 2019
# Date Modification : dimanche 09 juillet 2023
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
    info::String                   # description du moteur
    numSemaine::Int                # numéro de la semaine à construire  
    dctP                           # dictionnaire des Profs
    dctG                           # dictionnaire des Groupes
    dctS                           # dictionnaire des Salles
    collCreneauxAT                 # collection des créneaux à traiter
    collCreneauxF                  # collection des créneaux déjà "forcés"
    temperature::Float32           # "température" du moteur de recuit simulé
    numCr::Int                     # numéro du créneau en cours de traitement
    nbreTours::Int                 # nombre de tours de recuit simulé
    rendement::Float32             # rendement de placement de ce moteur
    energie::Int                   # fonction "énergie" à minimiser
    probaSecouage::Float32         # probabilité du "secouage" en cas de blocage
end

#= Prépare tous les éléments nécessaires au traitement d'une semaine.
Par défaut la collection de créneaux à placer est vide. Le moteur ne pourra
tourner que si le moteur est 'alimenté' en créneaux à traiter. =#
function prepareMoteur(numSemaine, numEDT)
    M = Moteur("",numSemaine,Dict(),Dict(),Dict(),[],[],0.0,0,0,0.0,0,MAX_PROBA)
    M.info = "*** Moteur n°$numEDT ***\n"
    lstCreneaux = analyseListeDesCreneaux(numSemaine)
    if ERR_Globales != ""           # vient du module 'Creneaux.jl'
        M.info = "Erreur !!!" * ERR_Globales
    else
        # Recherche les créneaux déjà pré-positionnés pour les mettre de côté
        for cr in lstCreneaux
            if cr.jour != "" && cr.horaire != ""
                push!(M.collCreneauxF, cr)    # créneaux 'F'orcés
            else
                push!(M.collCreneauxAT, cr)   # créneaux 'A' 'T'raiter
            end
        end
        chargeLesProfs(M)
        chargeLesSalles(M)
        chargeLesGroupes(M)                   # avec les parents/enfants
    end
    return M
end

### Permet de relire depuis le disque dur un fichier .dat sérialisé auparavant
function deserialiseFichierDat(fic)
    return deserialize(open(REPERTOIRE_DATA * SEP * fic * ".dat", "r"))
end

### Charge le planning de la semaine traitée pour chaque prof
function chargeLesProfs(M)
    for cr in M.collCreneauxAT
        if !(cr.prof in keys(M.dctP))
            M.dctP[cr.prof] = deserialiseFichierDat(cr.prof)[M.numSemaine]
        end
    end
end

### Charge le planning de la semaine traitée pour chaque salle
function chargeLesSalles(M)
    for cr in M.collCreneauxAT
        for salle in cr.salles
            # Le nom des salles est en MAJUSCULE sans espaces.
            salle = uppercase(replace(salle, " " => ""))
            if !(salle in keys(M.dctS))
                M.dctS[salle] = deserialiseFichierDat(salle)[M.numSemaine]
            end
        end
    end
end

### Charge le planning de la semaine traitée pour chaque groupe
function chargeLesGroupes(M)
    # Charge d'abord les groupes directement concernés par un créneau à placer
    for cr in M.collCreneauxAT
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

#= Fonction qui tente de déplacer un créneau vers une autre position. Elle
   retournera une variation d'énergie. Si cette variation est négative, le
   déplacement sera accepté, sinon, il le sera quand même mais avec une
   probabilité de plus en plus faible =#
function faitEvoluerLeSysteme(M)
    M.numCr = rand(1:length(M.collCreneauxAT))   # numéro aléatoire
    cr = M.collCreneauxAT[M.numCr]               # isole un créneau de la pile
    nbQH = Int(cr.dureeEnMin / 15)               # nombre de quarts d'heure
    # Obtenir le planning du prof concerné par le créneau
    plProf = M.dctP[cr.prof]                     # planning du prof (alias)
    #= Construire l'intersection du planning du groupe et de tous ses
       PERES/FILS, donc le planning de sa 'FAMILLE' complète. =#
    plGroupe = M.dctG[cr.groupe]                 # planning du groupe (alias)
    plFamille = PlanningSemaine(true)            # planning ENTIEREMENT vide
    plFamille = Intersection(plFamille, plGroupe)
    for e in rechercheFamilleDuGroupe(cr.groupe)
        plFamille = Intersection(plFamille, M.dctG[e])
    end
    #= Regarder déjà si le prof et le groupe peuvent coincider. Mais si le
       prof a le don d'ubiquité, on n'en tient pas compte. =#
    if lowercase(cr.prof) == lowercase(PROF_UBIQUITE)
        plProfGroupe = plFamille
    else
        plProfGroupe = Intersection(plProf, plFamille)
    end
    jour, debut = ouEstCePossible(nbQH, plProfGroupe) # tuple (j,d) ou (0,0)
    if jour != 0                             # ce serait possible...
        # Chercher si l'une des salles est disponible (priorité = ordre)
        for salle in cr.salles               # balaye toutes les salles
            # Par convention les salles sont en MAJUSCULE sans espace.
            salle = uppercase(replace(salle, " " => ""))
            #= Construction du planning mixant toutes les entités ; c'est
               donc celui dans lequel on cherchera une place possible au
               créneau (prof + groupe + salle).
               bas -> 'bac à sable'  =#
            plSalle = M.dctS[salle]
            if lowercase(salle) == lowercase(SALLE_UBIQUITE)
                bas = plProfGroupe    # on ne tient pas compte de la salle
            else
                bas = Intersection(plProfGroupe, plSalle)
            end
            jourFinal, debutFinal = ouEstCePossible(nbQH, bas)
            if jourFinal != 0                # on a trouvé !
                #= Calcule la différence d'énergie du possible changement, la
                   valeur sera négative si on trouve une meilleure place. =#
                ΔE = deltaEnergie(jourFinal, debutFinal, cr)
                # Retourne la variation d'énergie plus un tuple des infos
                return ΔE, (jourFinal, debutFinal, salle)
            end
        end
    end
    # On n'a pas trouvé de place, retourne 0 dans ΔE et comble le reste
    return 0, (0, 0, "")
end

#= Calcule la variation d'énergie d'un créneau s'il était placé ailleurs.
   La constante METHODE_ΔE indique quelle méthode utiliser.
=#
function deltaEnergie(jourFinal, debutFinal, cr)
    if METHODE_ΔE == "PAR_JOUR"
        # Elle "tasse" les créneaux vers le lundi mais charge les journées...
        # Elle a trop tendance à libérer les vendredi !
        ΔE = (jourFinal - cr.numeroDuJour) * NBCRENEAUX
        ΔE += debutFinal - cr.debutDuCreneau
        return ΔE
    elseif METHODE_ΔE == "PAR_TRANCHE"
        # Moins bien que "PAR_JOUR". Même si elle répartit mieux le matin, elle
        # place moins de créneaux au final.
        ΔE = (debutFinal - cr.debutDuCreneau) * 5
        ΔE += (jourFinal - cr.numeroDuJour)
        return ΔE
    elseif METHODE_ΔE == "PAR_EXPONENTIELLE"
        x = jourFinal
        y = (debutFinal-1)/4 + 8
        Ef = exp(α*x) - exp(α) + exp(β*y) - exp(β)
        x = cr.numeroDuJour
        y = (cr.debutDuCreneau-1)/4 + 8
        Ed = exp(α*x) - exp(α) + exp(β*y) - exp(β)
        ΔE = Ef-Ed
        return ΔE
    end
end

#= Positionne dans l'EDT les créneaux à traiter (ne s'occupe pas des créneaux
forcés). Ce sera la situation de départ de l'algorithme de recuit simulé sur
laquelle on calculera l'énergie du système au démarrage. =#
function positionneLesCreneauxAuDepart(M)
    shuffle!(M.collCreneauxAT)                   # mélange la collection
    #= Calcule la "surface" possible de chaque créneau et replace en
    tête de collection ceux qui ont le moins de possibilités côté prof =#
    listePourTri = []
    for cr in M.collCreneauxAT
        push!(listePourTri, (Surface(M.dctP[cr.prof]), cr))   # tuple (surf,cr)
    end
    sort!(listePourTri, by = x -> x[1])   # trie le tuple selon la surface
    empty!(M.collCreneauxAT)              # vide la collection
    for e in listePourTri
        push!(M.collCreneauxAT, e[2])     # reconstruit la collection mais triée
    end
    
    nbCrPlacés = 0   # pour comptabiliser ceux qui auront une place au départ
    for tour in 1:length(M.collCreneauxAT)       # tour sera un entier
        cr = M.collCreneauxAT[tour]              # isole un créneau de la pile
        nbQH = Int(cr.dureeEnMin / 15)           # nombre de quarts d'heure
        # Par défaut on positionne ce créneau le samedi matin à 8h
        cr.numeroDuJour = 6
        cr.debutDuCreneau = 1
        cr.nombreDeQuartDHeure = nbQH
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
        #= Regarder déjà si le prof et le groupe peuvent coincider. Mais si le
           prof a le don d'ubiquité, on n'en tient pas compte. =#
        if lowercase(cr.prof) == lowercase(PROF_UBIQUITE)
            plProfGroupe = plFamille
        else
            plProfGroupe = Intersection(plProf, plFamille)
        end
        jour, debut = ouEstCePossible(nbQH, plProfGroupe) # tuple (j,d) ou (0,0)
        if jour != 0                             # ce serait possible...
            # Chercher si l'une des salles est disponible (priorité = ordre)
            # Par défaut, cr.salleRetenue == ""
            for salle in cr.salles               # balaye toutes les salles
                # Par convention les salles sont en MAJUSCULE sans espace.
                salle = uppercase(replace(salle, " " => ""))
                #= Construction du planning mixant toutes les entités ; c'est
                   donc celui dans lequel on cherchera une place possible au
                   créneau (prof + groupe + salle).
                   bas -> 'bac à sable'
                =#
                plSalle = M.dctS[salle]
                if lowercase(salle) == lowercase(SALLE_UBIQUITE)
                    bas = plProfGroupe    # on ne tient pas compte de la salle
                else
                    bas = Intersection(plProfGroupe, plSalle)
                end
                jourFinal, debutFinal = ouEstCePossible(nbQH, bas)
                if jourFinal != 0                # on a trouvé !
                    nbCrPlacés += 1              # MAJ du comptage
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
                    break                        # quitte le 'for salle' car ok
                end
            end
        end
    end
    # Inscrit les 'performances' du moteur dans sa propre structure au départ
    nbCrPlacés += length(M.collCreneauxF)   # pour tenir compte des "forcés"
    nbTotalDeCr = length(M.collCreneauxAT) + length(M.collCreneauxF)
    M.rendement = round(10000 * nbCrPlacés / nbTotalDeCr) / 100
    M.info *= "Rendement initial : $(M.rendement) %  ($nbCrPlacés/$nbTotalDeCr)\n"
end

# Retire de l'EDT des créneaux déjà placés (utilise la proba du moteur)
function retireDesCreneauxSelonUneProbabilite(M)
    if M.probaSecouage < MIN_PROBA
        return     # pour ne pas "secouer" continuellement le système
    end
    for _ in 1:length(M.collCreneauxAT)
        if rand() < M.probaSecouage            # proba d'être "changé de place"
            cr = M.collCreneauxAT[M.numCr]     # isole un créneau de la pile
            j,d,n = cr.numeroDuJour, cr.debutDuCreneau, cr.nombreDeQuartDHeure
            if j != 6   # on ne touche pas à un créneau "non-placé" (6=samedi)
                LibereCreneau(M.dctP[cr.prof],j,d,n)          # libère le prof
                LibereCreneau(M.dctS[cr.salleRetenue],j,d,n)  # libère la salle
                LibereCreneau(M.dctG[cr.groupe],j,d,n)        # libère le groupe
                # Nettoie l'horaire du créneau ainsi que la salle retenue
                cr.numeroDuJour = 6     # remis le samedi
                cr.debutDuCreneau = 1   # à 8h
                cr.jour = cr.horaire = cr.salleRetenue = ""
            end
        end
    end
    M.probaSecouage -= PAS_PROBA    # fait évoluer la probabilité de "secouage"
end

### Fonction qui change de place un créneau suite à l'évolution du système
function changerPositionCreneau(M, infos)
    #= Le numéro du créneau à déplacer est connu via M.numCr qui a été déterminé
    dans la fonction "faitEvoluerLeSysteme(M)"  =#
    cr = M.collCreneauxAT[M.numCr]    # c'est un alias du créneau en fait
    # Enregistre la position actuelle du créneau et sa taille ...
    j1, d1, n1 = cr.numeroDuJour, cr.debutDuCreneau, cr.nombreDeQuartDHeure
    # ... et celle de sa position d'arrivée
    j2, d2, n2 = infos[1], infos[2], n1
    # Récupère le nom de la salle retenue (pas forcément la même qu'avant)
    salle = infos[3]
    #= Enlève le créneau des plannings si ce n'est pas un créneau "non-placé"
       qu'on reconnaît au fait que son jour est 6 (samedi) =#
    if j1 != 6 
        LibereCreneau(M.dctP[cr.prof], j1, d1, n1)            # libère le prof
        LibereCreneau(M.dctS[cr.salleRetenue], j1, d1, n1)    # libère la salle
        LibereCreneau(M.dctG[cr.groupe], j1, d1, n1)          # libère le groupe
    end
    # Puis le replace à sa nouvelle position
    AffecteCreneau(M.dctP[cr.prof], j2, d2, n2)
    AffecteCreneau(M.dctS[salle], j2, d2, n2)
    AffecteCreneau(M.dctG[cr.groupe], j2, d2, n2)
    # Enregistre aussi le changement dans la collection (via l'alias cr)
    cr.salleRetenue = salle
    cr.numeroDuJour = j2
    cr.debutDuCreneau = d2
    cr.jour, cr.horaire = convPosEnJH(j2, d2)
end


#= L'énergie du système est la somme des produits du jour par le numéro de
   début d'un créneau, les créneaux "non placés" étant par défaut positionnés
   le samedi (jour n°6) à 8h (deb=1).
   Comme cela, "avancer" un créneau d'une heure revient à abaisser l'énergie de
   4 (4 quarts d'heure). Avancer un créneau d'un jour fait baisser l'énergie de
   42 (car de 8h à 18h30 il y a 42 quarts d'heure dans une journée). =#
function calculeEnergieDuSysteme(M)
    # TODO: envisager de tenir compte de la durée des créneaux
    M.energie = 0
    for cr in M.collCreneauxAT
        # TODO: est-ce une bonne méthode de calcul ?
        M.energie += cr.numeroDuJour * cr.debutDuCreneau
    end
end

### Fonction qui va réellement calculer l'EDT d'une semaine ; reçoit un 'moteur'
function runMoteur(M)
    positionneLesCreneauxAuDepart(M)      # point de départ du système
    calculeEnergieDuSysteme(M)            # donne la fonction à minimiser
    M.info *= "Energie départ/finale : $(M.energie)/"
    M.temperature = T0                    # température initiale du système
    nbreToursSansChangement = 0
    statDeltaE = []   # INFO: tableau pour statistiques de "réglage" de l'algo
    while true                            # boucle d'évolution de la température
        M.nbreTours += 1                  # MAJ du numéro de tour
        nbTentatives = 0                  # initialisation des comptes
        nbTentativesReussies = 0
        for _ in 1:DUREE_EQUILIBRE_THERMIQUE
            ΔE, infos = faitEvoluerLeSysteme(M)  # joue avec le créneau M.numCr
            # INFO: stocke la somme des ΔE pour calculer leur moyenne
            if ΔE>0
                push!(statDeltaE, ΔE)
            end
            # Fin du INFO:
            nbTentatives += 1
            changerCreneau = false        # drapeau pour l'évolution
            if ΔE < 0                     # on va accepter ce changement
                changerCreneau = true
            elseif ΔE > 0   # si ΔE == 0 le créneau a repris sa place ou n'en a pas
                proba = exp(-ΔE/M.temperature)   # probabilité de l'échange
                if rand() < proba
                    changerCreneau = true
                end
            end
            if changerCreneau
                changerPositionCreneau(M, infos)
                calculeEnergieDuSysteme(M)
                nbTentativesReussies += 1
                nbreToursSansChangement = 0
            end
            if nbTentativesReussies >= NB_MAX_TENTATIVES_REUSSIES
                break  # sort du for "équilibre thermique"
            end
        end
        # Sortie de l'équilibre thermique (réussie ou pas...)
        if nbTentativesReussies == 0
            nbreToursSansChangement +=1
            retireDesCreneauxSelonUneProbabilite(M)
        end
        if nbreToursSansChangement == NB_MAX_DE_TOURS_SC
            # fin du calcul de l'EDT car plus aucune évolution du système
            break   # du while "température"
        end
        #= On baisse doucement la température du système donc cela baissera la
           probabilité d'accepter des changements "moins efficaces" =#
        M.temperature *= COEFF_DECROISSANCE_DE_T
    end
    calculeEnergieDuSysteme(M)
    M.info *= "$(M.energie)\n"
    # TODO: enlever plus tard
    #ΔEmoyen = sum(statDeltaE)/length(statDeltaE)
    #println("Moyenne des énergies : $ΔEmoyen")
end

### Fonction qui affiche l'emploi du temps calculé et l'enregistre dans un CSV
function afficheEnregistreEDT(M, numSemaine, tour)
    # Crée un fichier par tour, sur le modèle : s39_1, s39_2, etc.
    nom = REPERTOIRE_PLAN * SEP * string(numSemaine) * SEP
    nom *= "s" * string(numSemaine) * "_" * string(tour)
    touch(nom)    # Utile ???
    # Crée un nom de fichier pour les créneaux éventuellement non placés
    nom_np = nom * "_np.csv"
    touch(nom_np)   # ainsi le fichier sera créé, car sera éventuellement vide
    # Variable pour compter le nombre de créneaux réellement bien placés
    nbCrPlacés = 0
    # Variable drapeau pour n'afficher qu'une fois l'en-tête du CSV
    afficheHeader = true
    for e in M.collCreneauxAT
        # Remplit le CSV avec les créneaux placés ou non
        df = DataFrame(Formation = [e.onglet],
                       Jour = [e.jour], Heure = [e.horaire],
                       Type = [e.typeDeCours], Matière = [e.nomModule],
                       Prof = [e.prof], DureeEnMin = [e.dureeEnMin],
                       DureeEnHeure = [e.dureeEnMin]/60,                       
                       Salle = [e.salleRetenue], Groupe = [e.groupe])
        CSV.write(nom, df, header = afficheHeader, append = true, delim=';')
        afficheHeader = false    # les autres tours n'auront pas l'en-tête
        if e.jour in JOURS
            nbCrPlacés += 1
        else
            #= Le créneau désigné par 'e' n'a pas pu être placé. On va
               l'enregistrer à part dans un csv qui portera le même nom que
               celui des bons créneaux, mais avec '_np' avant l'extension =#
            df = DataFrame(Formation = [e.onglet],
               Type = [e.typeDeCours], Matière = [e.nomModule],
               Prof = [e.prof], DureeEnMin = [e.dureeEnMin],
               DureeEnHeure = [e.dureeEnMin]/60,                       
               Salle = [e.salleRetenue], Groupe = [e.groupe])
            CSV.write(nom_np, df, header = false, append = true, delim=';')
        end
    end
    for e in M.collCreneauxF
        # Remplit le CSV avec les créneaux forcés au départ depuis l'interface
        df = DataFrame(Formation = [e.onglet],
                       Jour = [e.jour], Heure = [e.horaire],
                       Type = [e.typeDeCours], Matière = [e.nomModule],
                       Prof = [e.prof], DureeEnMin = [e.dureeEnMin],
                       DureeEnHeure = [e.dureeEnMin]/60,                       
                       Salle = [e.salleRetenue], Groupe = [e.groupe])
        CSV.write(nom, df, header = false, append = true, delim=';')
    end
    strStat = " (" * string(nbCrPlacés + length(M.collCreneauxF)) * "/" 
    strStat *= string(length(M.collCreneauxAT)+length(M.collCreneauxF)) * ")"
    # Inscrit les 'performances' du moteur dans sa propre structure
    M.rendement = round(10000 * nbCrPlacés / length(M.collCreneauxAT)) / 100
    M.info *= "[--- Rendement final : $(M.rendement)% $strStat  ---]\n"
    M.info *= "Nombre d'itérations : $(M.nbreTours)\n"
    println(M.info)
    #= Renomme le fichier pour ajouter le rendement (sous forme d'un entier),
       l'énergie et l'extension .csv 
       Un fichier aura alors un nom du type : s39_1_9856_3997.csv =#
    nouvNom = nom * "_" * string(Int(trunc(M.rendement*100))) * "_"
    nouvNom *= string(M.energie) * ".csv"
    mv(nom, nouvNom)
    # Copie ce fichier sous un nom plus court (pour le programme de visu)
    # Ainsi, s39_1_9856_3997.csv sera aussi connu sous le nom s39_1.csv
    cp(nouvNom, nom * ".csv")
end

#######################
### PROGRAMME PRINCIPAL
#######################
function programmePrincipal(semaine, nbEDTCalcules)
    # Cette fonction principale a été appelée depuis une route de webAPI.jl
	semaine = Base.parse(Int64, semaine)
	nbEDTCalcules = Base.parse(Int64, nbEDTCalcules)
    # Supprime si possible le dossier qui contiendra les plannings de la semaine
    rm(REPERTOIRE_PLAN * SEP * string(semaine), force=true, recursive=true)
    # Recrée le dossier (il est donc vide)
    mkdir(REPERTOIRE_PLAN * SEP * string(semaine))
    #= Crée un tableau vide qui contiendra un tuple (rendement, energie) par
      tour de moteur. Ce tableau sera ensuite trié par ordre décroissant pour
      connaître le numéro du tour du meilleur score obtenu par le moteur. =#
    scoreDesTours = []
    println("-------------Traitement de la semaine n°$semaine--------------")
    #-------------------------------------------------------------------------
    # TODO: CETTE PARTIE DEVRAIT ÊTRE LANCÉE VIA DES THREADS !!!
    for numEDT in 1:nbEDTCalcules
        begin
            moteur = prepareMoteur(semaine, numEDT)
            runMoteur(moteur)
            afficheEnregistreEDT(moteur, semaine, numEDT)
        end
        # Enregistre les scores comme des tuples (rendement, energie, n°)
        push!(scoreDesTours, (moteur.rendement, moteur.energie, numEDT))
	end
    # FIN DU TODO:

    #-------------------------------------------------------------------------
    # Trie le tableau des scores par ordre décroissant
    sort!(scoreDesTours, by=((x,y),) -> (-x,y))
    println("Le meilleur planning est le numéro $(scoreDesTours[1][3])")
    println("avec un rendement de $(scoreDesTours[1][1])%")
    #= Crée un fichier texte dans le répertoire avec à chaque ligne :
       numEDT;rendement =#
    lignes = ""
    for numEDT in 1:nbEDTCalcules
        lignes *= string(scoreDesTours[numEDT][3]) * ";"
        lignes *= string(scoreDesTours[numEDT][1]) * "\n"
    end
    # Chemin du fichier présentant les classements des plannings générés
    cf = REPERTOIRE_PLAN * SEP * string(semaine) * SEP * NOM_FICHIER_CLASSEMENT
    write(cf, lignes)
    # Retourne la chaîne de texte contenant les plannings triés par rendement
    return lignes
end
