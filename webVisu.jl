#= 
Visu pour le système de création automatique d'emploi du temps (écrit en julia)
Auteur : Philippe Belhomme
Dates de création : vendredi 26 août 2022
  de modification : lundi 29 août 2022
=#

using Gtk
include("CONSTANTES.jl")        # pour importer les constantes du système

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
  # Affichage du jour en ligne 1, sur n colonnes
  for j in 1:length(JOURS)
    b = GtkButton(JOURS[j])
    c = 2 + (j-1)*n
    grille[c : c+n-1, 1] = b
  end
end

# Fenêtre principale et sa grille
win = GtkWindow("Planning EDT...")
grille = GtkGrid()
set_gtk_property!(grille, :column_homogeneous, true)
set_gtk_property!(grille, :column_spacing, 4)  # gap in pixels between columns

afficheLesHeuresDansLaGrille()
afficheLesJoursDansLaGrille(4)

# Affichage d'un cours et un TP
fic = "s36_1.csv"
LstCr = readlines(open(REPERTOIRE_PLAN * SEP * "36" * SEP * fic, "r"))
tabCr = split(LstCr[37],';')
jourEnLettres = tabCr[2]
matiere = tabCr[3]
type = tabCr[4]
heure = tabCr[6]
dureeEnMin = string(tabCr[7])
prof = tabCr[8]
salle = tabCr[9]
println(tabCr)
jour, deb = convJHEnPos(jourEnLettres, heure)
dureeEnQH = Int(Base.parse(Int64, dureeEnMin)/15)
b = GtkButton(type * " " * matiere * "\n" * prof * "\n" * salle)
grille[(jour-1)*4+2:(jour-1)*4+2+3, deb+1:deb+1+dureeEnQH] = b

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