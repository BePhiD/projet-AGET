# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme
# Date Création : lundi 03 juillet 2023
# Date Modification : lundi 03 juillet 2023
# Langage : Julia

# Module : importExcelPrevisionnel.jl
# Pour importer la liste des enseignements prévus d'une semaine donnée
# Le fichier Excel provient du système de gestion d'EDT GIM/GEII

using XLSX
include("CONSTANTES.jl")        # pour importer les constantes du système

NOM_ONGLET = "semaine"
PREMIERE_CELLULE_PROMO = "A4"

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


# Fonction qui ouvre le fichier Excel et retourne la feuille de travail
function ouvreLaFeuilleDeTravail(fichierExcel)
    XLSX.readxlsx(fichierExcel)[NOM_ONGLET]
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
   (ou juste le nom d'une salle).
   La fonction retourne le dictionnaire =#
   function listeDesSalles()
    dds = Dict()                            # dictionnaire des salles
    xf = XLSX.readxlsx(LISTE_SALLES)
    for promo in XLSX.sheetnames(xf)
        ligne = 2                           # car il y a une ligne d'en-tête
        while !ismissing(xf[promo][ligne, 1])
            typeEns = xf[promo][ligne, 1]
            matiere = xf[promo][ligne, 2]
            cleDictionnaire = promo * SEP * typeEns * SEP * matiere
            valeur = xf[promo][ligne, 3]
            dds[cleDictionnaire] = valeur
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
        # Un type d'enseignement est un texte avec rien sur sa droite
        if !ismissing(feuille[ligne, 1]) && ismissing(feuille[ligne, 2])
            typeEns = feuille[ligne, 1]
            lt = ligne + 1                  # ligne de travail = la suivante
            while !ismissing(feuille[lt,1]) # balaye les lignes non vides
                ct = 1                      # colonne de travail
                while !ismissing(feuille[lt,ct])
                    matiere = feuille[lt,ct]
                    promo = feuille[lt,ct+1]
                    prof = feuille[lt,ct+2]
                    if ismissing(prof)
                        prof = "inconnu"    # en projet, pas de prof désigné
                    end
                    dureeEnMin = Int64(feuille[lt,ct+3] * 60)
                    cleDictionnaire = zone.nom * SEP * typeEns * SEP * matiere
                    try
                        salle = dicoDesSalles[cleDictionnaire]
                    catch e
                        salle = missing
                        print("ERREUR !!! Salle non précisée pour : ")
                        println(cleDictionnaire)
                    end
                    if ismissing(salle)
                        salle = "missing"
                    end
                    crP = creneauPrevisionnel(zone.nom,
                                              typeEns,
                                              matiere,
                                              promo * '-' * zone.nom,
                                              prof,
                                              dureeEnMin,
                                              salle)
                    push!(LCP, crP)
                    ct += 4                 # prochain créneau 4 cols à droite
                end
                lt += 1
            end
        end
    end
    return LCP
end


# Fonction principale qui sera appelée depuis l'interface graphique Web
function importFichierExcel(fichierExcel::AbstractString, semaine::Number)
    println("--------------- !!! COUCOU !!! -----------------")
    feuille = ouvreLaFeuilleDeTravail(fichierExcel)

    numSemaine = trouveLeNumeroDeSemaine(feuille)
    if numSemaine != semaine
        println("Ce n'était pas la semaine attendue !")
        println("J'ai trouvé $numSemaine alors que j'attendais $semaine...")
        return nothing
    end

    listeDesPromos = trouveLesPromos(feuille)
    if length(listeDesPromos) == 0
        println("Désolé, je n'ai trouvé aucune promo dans le fichier Excel...")
        return nothing
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
#liste = importFichierExcel("Psemaine49geiiPourPhilippe.xlsx", 49)   # test !
#println(liste)
