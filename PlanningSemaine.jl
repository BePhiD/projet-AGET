# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme
# Date Création : Vendredi 28 décembre 2018
# Date Modification : Vendredi 08 mars 2019
# Langage : Julia

# Module : PlanningSemaine
# Contient la définition d'un planning d'une semaine et des fonctions associées

include("CONSTANTES.jl")      # pour importer les constantes du système

function PlanningSemaine(vide=false)
    #= Tableau de créneaux, tous mis à true par défaut (donc libres).
       Chaque créneau dure 15 mn (plus petite division d'horaire).
       Il y a NBJOURS lignes (commence à 1 pour lundi) et
       NBCRENEAUX colonnes (42 si horaire de 8h à 18h30).
       matrice[3][5] désigne donc le mercredi de 9h à 9h15.
       Si 'vide' est vrai, on ne retire pas les créneaux interdits. =#
    P = fill(true, (NBJOURS,NBCRENEAUX))
    if !vide RetireCreneauxInterdits(P) end
    return P
end

function AffecteCreneau(P, jour, deb, nb, value=false)
    #= Affecte un créneau dans la matrice P désigné par son jour, le rang du
       début et le nombre de cases successives. Pour bloquer un créneau on le
       positionne à false (défaut). Pour le libérer on lui affectera true. =#
    P[jour,deb:deb+nb-1] .= value
end

function LibereCreneau(P, jour, deb, nb)
    #= Libère un créneau dans P désigné par son jour, le rang de début et le
       nombre de cases successives. =#
    AffecteCreneau(P, jour, deb, nb, true)
end

function RetireCreneauxInterdits(P)
    # Positionne à false les créneaux listés comme interdits.
    for ci in CRENEAUX_INTERDITS AffecteCreneau(P,ci[1],ci[2],ci[3]) end
end

function AffecteCreneauHoraireDuree(P, jour, heure, mn, duree, value=false)
    #= Affecte un créneau dans P désigné par son jour, l'horaire de début et
       la durée en minutes (multiples de 15). Pour bloquer un créneau on le
       positionne à false. Pour le libérer on lui attribuera true. =#
    deb , nb = Int8((heure - HEUREDEB) * 4 + mn/15 + 1), Int8(duree/15)
    #TODO : assert deb>0 et duree<len(ligne de matrice) - deb
    AffecteCreneau(P, jour, deb, nb, value)
end

function LibereCreneauHoraireDuree(P, jour, heure, mn, duree)
    #= Libère un créneau dans P désigné par son jour, l'horaire de début et
       la durée en minutes (multiples de 15). =#
    AffecteCreneauHoraireDuree(P, jour, heure, mn, duree, true)
end

function Intersection(P, autres...)
    #= Effectue l'intersection entre le planning P et ceux passés en paramètre.
       Retourne une copie du planning P =#
    nP = copy(P)
    for e in autres   nP = nP .& e   end
    return nP
end

function LibereSemaine(P)
    # Libère tous les créneaux du planning P (remplit avec 'true').
    return P .| true
end

function BloqueSemaine(P)
    # Bloque tous les créneaux du planning P (remplit avec 'false').
    return P .& false
end

function ouEstCePossible(nbQH,P)
    #= Recherche la 1ère position possible pour placer un créneau de longueur
       nbQH quarts d'heure dans le planning P. Retourne un tuple (jour, deb)
       si possible, sinon (0,0).
       Calcule en fait une sorte de 'corrélation' entre chaque ligne de P et le
       vecteur représentant le créneau C (transposé ici) et fait la somme des
       valeurs 'true'. Un créneau est possible quand la somme correspond
       justement à la longueur du vecteur C. =#
    C = fill(true,(1,nbQH))      # vecteur 1 ligne de nbQH valeurs 'true'
    n,m = size(P)[2],length(C)   # longueur d'un jour et d'un créneau
    for i=1:NBJOURS , j=1:n-m+1  # i balaye les jours, j les débuts de créneau
        M = P[i,1:n]             # une ligne de P donc une journée
        if sum(M[j:j+m-1] .& C') == m
            return (i,j)         # pourra être converti avec convPosEnJH(x,y)
        end
    end
    return (0,0)
end

function estPossibleIci(P, jour, deb, nb)
    #= Vérifie si un créneau de taille 'nb' quart d'heures peut se placer tel
       'jour' à telle position 'deb' (entre 1 et 44).
       Utile notamment pour déterminer quelle salle parmi plusieurs possibles
       pourrait accueillir le créneau. =#
    sum(P[jour, deb:deb+nb-1]) == nb ? true : false
end

### PROGRAMME PRINCIPAL (pour tests...)
#=
P1 = PlanningSemaine()
P1 = BloqueSemaine(P1)
LibereCreneauHoraireDuree(P1, 5, 14, 30, 60)
LibereCreneauHoraireDuree(P1, 2, 9, 30, 180)
(x,y) = ouEstCePossible(6,P1)
println(x," , ",y)
if (x,y) != (0,0)
    j,h = convPosEnJH(x,y)
    println(j," , ",h)
end
println(estPossibleIci(P1, 2, 7, 4))
=#
