# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme
# Date Création : lundi 03 juillet 2023
# Date Modification : dimanche 09 juillet 2023
# Langage : Julia

# Module : importExcelPrevisionnel.jl
# Pour importer la liste des enseignements prévus d'une semaine donnée
# Le fichier Excel provient du système de gestion d'EDT GIM/GEII

using XLSX
include("CONSTANTES.jl")        # pour importer les constantes du système

NOM_ONGLET = "semaine"
PREMIERE_CELLULE_PROMO = "A4"
LIMITE_NB_LIGNES = 1000         # pour limiter la recherche si feuille entière

mutable struct zonePromo
    nom::String
    ligneDebut::Int64
    ligneFin::Int64
end

struct creneauPrevisionnel
    promo::String
    typeEns::String
    matiere::String
    groupe::String
    prof::String
    dureeEnMin::Int64
    salle::String
end


#= Fonction qui ouvre le fichier Excel et retourne la feuille de travail ou
   nothing s'il y a eu une erreur =#
function ouvreLaFeuilleDeTravail(fichierExcel)
    try
        XLSX.readxlsx(fichierExcel)[NOM_ONGLET]
    catch e
        nothing
    end
end


# Extrait le numéro de semaine depuis le dernier "mot" de la cellule A4
# Renvoie le numéro de semaine sous forme d'un entier
function trouveLeNumeroDeSemaine(feuille)
    # TODO: peut-être se servir de la 1ère promo trouvée par "trouveLesPromos" ?
    # Dans la ligne suivante il faut préfixer parse par 'Base' car l'appel peut
    # provenir d'un fichier dans lequel parse a été 'surchargée' par la fonction
    # présente dans le module JSON.
    Base.parse(Int64, split(feuille[PREMIERE_CELLULE_PROMO], ' ') |> last)
end


# Fonction qui construit la liste des promos en délimitant leur zone d'influence
function trouveLesPromos(feuille)
    listePromo = []                        # liste qui contiendra des zonePromo
    nbLignes, nbCols = size(feuille[:])    # nb de lignes/colonnes de la feuille
    if nbLignes > LIMITE_NB_LIGNES         # car parfois nbLignes == 1048576 !
        println("Nombre de lignes : $nbLignes et nombre de colonnes : $nbCols")
        # On va chercher la dernière ligne non vide en partant de la limite
        nbLignes = LIMITE_NB_LIGNES
        while ismissing(feuille[nbLignes, 1])
            nbLignes -= 1                  # on recule d'une ligne
        end
        nbLignes += 1                      # on en ajoute une par sécurité
        println("Nombre de lignes retenues : $nbLignes")
    end
    for ligne in 1:nbLignes
        for colonne in 1:nbCols
            try
                # Chaque cellule commençant par "PREV..." correspond à une promo
                if startswith(feuille[ligne, colonne], "PREVISIONS")
                    s = split(feuille[ligne, colonne], ' ')
                    promo = s[5] * '-' * s[6]   # ex de promo : "GIM-S1-S2"
                    p = zonePromo(promo, ligne, -1)   # la ligneFin est inconnue
                    push!(listePromo, p)
                end
            catch e
            end
        end
    end
    # Délimite la fin de zone d'influence d'une promo par rapport à la suivante
    for i in 1:length(listePromo)-1
        listePromo[i].ligneFin = listePromo[i+1].ligneDebut - 1
    end
    # La fin de la la dernière promo devient la dernière ligne de la feuille
    listePromo[length(listePromo)].ligneFin = nbLignes
    return listePromo
end


#= Fonction qui lit les salles associées à des enseignements et en déduit un
   dictionnaire dont la clé sera formée par  : la promo + le type de cours +
   la matière ; la valeur sera une liste de salles séparées par des virgules
   (ou juste le nom d'une salle). La fonction retourne le dictionnaire =#
   function listeDesSalles()
    dds = Dict()                            # dictionnaire des salles
    xf = XLSX.readxlsx(LISTE_SALLES)        # lit le fichier Excel
    for promo in XLSX.sheetnames(xf)        # balaye tous les onglets
        ligne = 2                           # car il y a une ligne d'en-tête
        while !ismissing(xf[promo][ligne, 1])
            # On enlève au passage les éventuels '.' comme dans "T.D." par ex
            typeEns = replace(xf[promo][ligne, 1], "." => "")
            matiere = xf[promo][ligne, 2]
            sallesPrevues = xf[promo][ligne, 3]
            cleDictionnaire = promo * SEP * typeEns * SEP * matiere
            # On force la clé du dictionnaire à être en MAJUSCULE
            dds[uppercase(cleDictionnaire)] = sallesPrevues
            ligne += 1
        end
    end
    return dds
end


# Fonction qui fabrique la liste des créneaux prévus pour une "promo"
function extraitLesCreneauxDeLaZone(feuille, zone, dicoDesSalles)
    LCP = []                                # Liste de Créneaux Prévisionnels
    # Se limite aux lignes concernées par la promo (la zone d'influence)
    for ligne in zone.ligneDebut:zone.ligneFin
        #= Un type d'enseignement est un texte avec rien sur sa droite. On
           enlève au passage les éventuels '.' comme dans "T.D." par exemple.=#
        if !ismissing(feuille[ligne, 1]) && ismissing(feuille[ligne, 2])
            typeEns = replace(feuille[ligne, 1], "." => "")
            lt = ligne + 1                  # ligne de travail = la suivante
            while !ismissing(feuille[lt,1]) # balaye les lignes non vides
                ct = 1                      # colonne de travail au départ
                while !ismissing(feuille[lt,ct])
                    matiere = feuille[lt,ct]
                    # Les noms de promo sont mis forcément en MAJUSCULE
                    promo = uppercase(feuille[lt,ct+1])
                    DEBUG_LOG(promo)
                    if ismissing(feuille[lt,ct+2])
                        prof = PROF_UBIQUITE   # en projet, pas de prof désigné
                    else
                        # Dans les noms de prof, les espaces sont remplacés par '-'
                        prof = replace(feuille[lt,ct+2], " " => "-")
                    end
                    DEBUG_LOG(prof)
                    # Teste l'existence du prof
                    if checkExistanceProf(prof) == "false"
                        insereProf(prof)
                    end
                    dureeEnMin = Int64(feuille[lt,ct+3] * 60)
                    cleDictionnaire = zone.nom * SEP * typeEns * SEP * matiere
                    try
                        # La clé de dictionnaire est TOUJOURS en MAJUSCULE
                        salles = dicoDesSalles[uppercase(cleDictionnaire)]
                    catch e
                        salles = missing
                        print("ATTENTION ! Salles non précisées pour : ")
                        println(cleDictionnaire, " --> \"missing\"")
                    end
                    if ismissing(salles)    # en principe ne devrait pas arriver
                        salles = "missing"
                    end
                    DEBUG_LOG(salles)
                    #= Teste l'existence de chaque salle possible du créneau.
                       Par convention, une salle ne contiendra jamais d'espace
                       et sera toujours mise en majuscule ==> erreurs évitées =#
                    for salle in split(salles, ",")
                        salle = uppercase(replace(salle, " " => ""))
                        if checkExistanceSalle(salle) == "false"
                            insereSalle(salle)
                        end
                    end
                    crP = creneauPrevisionnel(zone.nom,
                                              typeEns,
                                              matiere,
                                              promo * '-' * uppercase(zone.nom),
                                              prof,
                                              dureeEnMin,
                                              salles)
                    push!(LCP, crP)
                    ct += 4                 # prochain créneau 4 cols à droite
                end
                lt += 1                     # on passe à la ligne suivante
            end
        end
    end
    return LCP
end


#= Fonction qui sera appelée depuis l'interface graphique Web. Elle retourne
   soit un message d'erreur qui commence par 'ERREUR', soit la liste des
   créneaux prévisionnels (des objets de la structure creneauPrevisionnel) =#
function importFichierExcel(fichierExcel::AbstractString, semaine::Number)
    feuille = ouvreLaFeuilleDeTravail(fichierExcel)
    if isnothing(feuille)
        message = "ERREUR ! Ce n'est pas un fichier Excel valide..."
        return message
    end

    numSemaine = trouveLeNumeroDeSemaine(feuille)
    if numSemaine != semaine
        message = "ERREUR ! Ce n'était pas la semaine attendue...\n"
        message *= "J'ai trouvé $numSemaine alors que j'attendais $semaine."
        return message
    end

    listeDesPromos = trouveLesPromos(feuille)
    if length(listeDesPromos) == 0
        message = "ERREUR ! Aucune promo trouvée dans le fichier Excel..."
        return message
    end

    dictionnaireDesSalles = listeDesSalles()

    listeCrPrev = []
    for liste in listeDesPromos
        LP = extraitLesCreneauxDeLaZone(feuille, liste, dictionnaireDesSalles)
        listeCrPrev = cat(listeCrPrev, LP, dims=1)
    end
    return listeCrPrev
end

#######################
### PROGRAMME PRINCIPAL
#######################
#= liste = importFichierExcel("Psemaine49geiiPourPhilippe.xlsx", 49)   # test !
println(liste) =#
