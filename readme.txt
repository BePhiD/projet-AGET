Tester avec la semaine n°49, elle contient 213 créneaux !


*** Pour travailler en mode graphique :
julia webAPI.jl
un serveur est lancé sur le port 8000
attendre un peu...
Ouvrir ensuite la page :  planificationSemaine.html dans un navigateur



*** Pour travailler en "manuel", lancer le programme Moteur comme ceci :
julia MoteurRecuitSimule.jl 49

# Problème de version du package CSV dans julia (pour EDTAutomatique)...
# Afficher la liste des packages installés
julia
] st
# le package CSV est en version v0.10.0


# Installer une version plus récente
julia
] add CSV@v0.10.2
# et là toute une liste de nouveaux packages s'installe !!!
