# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme
# Date Création : Lundi 31 décembre 2018
# Date Modification : Vendredi 24 mai 2019
# Langage : Julia

# Module : Groupes
# Gestion des Groupes CM/TD/TP avec pour chacun un planning annuel de semaines.
# Une fonction permet de créer la hiérarchie 'père->fils' des groupes.

include("CONSTANTES.jl")             # pour importer les constantes du système
include("PlanningSemaine.jl")        # pour importer la gestion des plannings
using Serialization                  # pour sauvegarder les fichiers planning

# Structure de base d'un noeud 'père->fils'.
# Chaque membre contiendra un tableau de chaînes de caractères.
struct noeud
    pere::Array{String,1}
    fils::Array{String,1}
end
# Constructeur d'un noeud (fournit 2 tableaux vides aux pere et fils)
nouveauNoeud() = noeud([],[])
# Dictionnaire de la hiérarchie des groupes
hierarchieGroupes = Dict()

function analyseListeDesGroupes()
    # Lecture du fichier de config des groupes (de la forme 'fils<pere')
    lstRelations  = readlines(open(REPERTOIRE_CFG * '/' * LISTE_GROUPES, "r"))
    fichiersPresents = readdir(REPERTOIRE_DATA)
    lstGroupes = []                # groupes déduits des relations 'fils<père'
    # Création des groupes pas encore sérialisés
    for e in lstRelations
        if startswith(strip(e),'#') continue end    # on saute les commentaires
        if length(strip(e)) == 0 continue end       # on saute les lignes vides
        # Extrait les noms qui apparaîssent autour du '<' (élimine les ' ')
        ids = split(strip(e),'<')
        # Stocke ces noms dans la liste des groupes s'ils n'y sont pas encore
        if !(strip(ids[1]) in lstGroupes) push!(lstGroupes, strip(ids[1])) end
        if !(strip(ids[2]) in lstGroupes) push!(lstGroupes, strip(ids[2])) end
    end
    for id in lstGroupes
        if !(id * ".dat" in fichiersPresents)
            # Crée un nouvel élément et génère son fichier ".dat" pour l'année
            P = []                   # tableau vide (contiendra 52 plannings)
            for x in 1:NBSEMAINES  push!(P, PlanningSemaine())  end
            io = open(REPERTOIRE_DATA * '/' * id * ".dat", "w")
            serialize(io, P)         # stocke sur disque le planning annuel
            close(io)
            push!(fichiersPresents, id * ".dat")  # ajoute le nouveau fichier
            print("Objets Groupes à créer : ")
            println(id, "...OK.")
        end
    end
    construitHierarchieDesGroupes()  # --> variable globale 'hierarchieGroupes'
end

function construitHierarchieDesGroupes()
    #= Construit un dictionnaire de la hiérarchie des groupes promo/TD/TP.
       Stocke cette hiérarchie dans un dictionnaire de 'noeuds' ; les clés du
       dictionnaire sont les noms des groupes, les champs 'pere' et 'fils' sont
       des tableaux de Strings pointant vers d'autres clés. =#
    lstRelations  = readlines(open(REPERTOIRE_CFG * '/' * LISTE_GROUPES, "r"))
    # Obtention des relations 'fils<pere'
    for e in lstRelations
        if startswith(strip(e),'#') continue end    # on saute les commentaires
        if length(strip(e)) == 0 continue end       # on saute les lignes vides
        # Extrait les noms qui apparaîssent autour du '<' (élimine les ' ')
        fils = strip(split(strip(e),'<')[1])
        pere = strip(split(strip(e),'<')[2])
        # Crée les groupes dans le dictionnaire s'ils n'y sont pas
        if !(pere in keys(hierarchieGroupes))
            hierarchieGroupes[pere] = nouveauNoeud()
        end
        if !(fils in keys(hierarchieGroupes))
            hierarchieGroupes[fils] = nouveauNoeud()
        end
        # Attache le père et le fils entre eux
        if !(fils in hierarchieGroupes[pere].fils)
            push!(hierarchieGroupes[pere].fils, fils)
        end
        if !(pere in hierarchieGroupes[fils].pere)
            push!(hierarchieGroupes[fils].pere, pere)
        end
    end
end

function rechercheFamilleDuGroupe(nom)
    # Recherche toute la famille d'un groupe (ascendants et descendants)
    # Recherche des ascendants du groupe 'nom'
    ascendants = []
    # On place d'abord la génération juste au-dessus, si elle existe
    if ! isempty(hierarchieGroupes[nom].pere)
        for p in hierarchieGroupes[nom].pere push!(ascendants, p) end
        # Puis on cherche à placer les générations précédentes
        onContinue = true
        while onContinue
            onContinue = false                # baisse le 'drapeau'
            for p in ascendants
                if ! isempty(hierarchieGroupes[p].pere)
                    for pp in hierarchieGroupes[p].pere
                        if !(pp in ascendants)
                            push!(ascendants, pp)
                            onContinue = true     # garanti de continuer
                        end
                    end
                end
            end
        end
    end
    # Recherche des descendants du groupe 'nom'
    descendants = []
    # On place d'abord la génération juste au-dessous, si elle existe
    if ! isempty(hierarchieGroupes[nom].fils)
        for f in hierarchieGroupes[nom].fils push!(descendants, f) end
        # Puis on cherche à placer les générations suivantes
        onContinue = true
        while onContinue
            onContinue = false                # baisse le 'drapeau'
            for f in descendants
                if ! isempty(hierarchieGroupes[f].fils)
                    for ff in hierarchieGroupes[f].fils
                        if !(ff in descendants)
                            push!(descendants, ff)
                            onContinue = true     # garanti de continuer
                        end
                    end
                end
            end
        end
    end
    famille = append!([], ascendants) ; famille = append!(famille, descendants)
    return famille
end

### PROGRAMME PRINCIPAL
analyseListeDesGroupes()
#f = rechercheFamilleDuGroupe("GIM1A-TD2")
#println(f)
