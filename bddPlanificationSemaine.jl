# Projet : AUTOMATIC-EDT
# Auteur : Philippe Belhomme (+ Swann Protais pendant son stage de DUT INFO)
# Date Création : mercredi 09 février 2022
# Date Modification : dimanche 09 juillet 2023
# Langage : Julia

# Module : bddPlanificationSemaine
# Gestion de la BDD qui enregistre les créneaux prévus à l'emploi du temps.
# Les créneaux font partie d'une promo ou bien sont dans une corbeille.

include("CONSTANTES.jl")        # pour importer les constantes du système
using SQLite
using CSV
using DataFrames
using UUIDs


# Réinitialise toutes les données, vidant la BDD SQLite de toutes informations
function viderToutesInfos()
  creeFichierEtTableBDD()
  rm(REPERTOIRE_SEM, recursive=true)
  mkdir(REPERTOIRE_SEM)
  rm(REPERTOIRE_PLAN, recursive=true)
  mkdir(REPERTOIRE_PLAN)
end

# Crée la table previsionnelEDT si elle n'existe pas
function creeFichierEtTableBDD()
#= Fonction qui devrait être appelée une seule fois, pour créer la BDD
   contenant tous les créneaux inscrits dans le prévisionnel. Certains seront
   associés à une promo (ex : GIM-1A-FI) alors que d'autres seront dans la
   "corbeille" =#
   reqCreation = """CREATE TABLE IF NOT EXISTS previsionnelEDT (
       uuid VARCHAR(36) PRIMARY KEY NOT NULL,
       numSemaine INTEGER,
       tab VARCHAR(30),
       typeDeCours VARCHAR(30),
       nomModule VARCHAR(30),
       prof VARCHAR(30),
       salles VARCHAR(80),
       groupe VARCHAR(30),
       dureeEnMin INTEGER,
       nomDuJour VARCHAR(20) DEFAULT "",
       horaire VARCHAR(20) DEFAULT "",
       salleRetenue VARCHAR(20) DEFAULT ""
   )"""
   # Ouvre la base de données (mais si le fichier n'existe pas il est créé)
   db = SQLite.DB(NOM_DATABASE_EDT)
   reqsup = """DROP TABLE IF EXISTS previsionnelEDT"""
   SQLite.execute(db, reqsup)
   # Crée la table (TODO: devrait être vidée chaque année !)
   SQLite.execute(db, reqCreation)
end

# Insère un prof depuis la page de semaine
function insereProf(nomProf)
    req = """ INSERT INTO professeurs VALUES("$nomProf") """
    DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req)
    creeFichierDatPourProfOuSalle(nomProf, "Création du prof : ")
end

# Supprime un prof de la table depuis la page de planning semaine (via popup)
function supprimeProf(nomProf)
    #TODO: on devrait vérifier s'il n'est pas utilisé dans un planning !!!
    req = """ DELETE FROM professeurs where nomProf = "$nomProf" """
    DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req)
    # Supprime aussi le .dat du prof
    try
        rm(REPERTOIRE_DATA * SEP * nomProf * ".dat")
    catch
        println("Le fichier .dat du prof ", nomProf, " n'existait pas...")
    end
end

# Insère une salle dans la base de données
function insereSalle(nomSalle)
    req = """ INSERT INTO salles VALUES("$nomSalle") """
    DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req)
    creeFichierDatPourProfOuSalle(nomSalle, "Création de la Salle : ")
end

# Supprime une salle de la table depuis la page de planning semaine (via popup2)
function supprimeSalle(nomSalle)
    #TODO: on devrait vérifier si elle n'est pas utilisée dans un planning !!!
    req = """ DELETE FROM salles where nomSalle = "$nomSalle" """
    DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req)
    # Supprime aussi le .dat de la salle
    try
        rm(REPERTOIRE_DATA * SEP * nomSalle * ".dat")
    catch
        println("Le fichier .dat de la salle ", nomSalle, " n'existait pas...")
    end
end

# Supprime et recrée la table des professeurs
function creeFichierEtTableProf()
#= Fonction qui devrait être appelée une seule fois, pour créer la table
   contenant tous les profs.  =#
   db = SQLite.DB(NOM_DATABASE_EDT)
   reqSup = """DROP TABLE IF EXISTS professeurs"""
   SQLite.execute(db, reqSup)
   reqCreation = """CREATE TABLE IF NOT EXISTS professeurs (
       nomProf VARCHAR(30) PRIMARY KEY NOT NULL
   )"""
   SQLite.execute(db, reqCreation)
end

# Supprime et recrée la table des salles
function creeFichierEtTableSalles()
#= Fonction qui devrait être appelée une seule fois, pour créer la table
   contenant toutes les salles.  =#
   db = SQLite.DB(NOM_DATABASE_EDT)
   reqSup = """DROP TABLE IF EXISTS salles"""
   SQLite.execute(db, reqSup)
   reqCreation = """CREATE TABLE IF NOT EXISTS salles (
       nomSalle VARCHAR(20) PRIMARY KEY NOT NULL
   )"""
   SQLite.execute(db, reqCreation)
end

# Remplit le CSV previsionnel
function createCSVcreneau(numSemaine, matiere, typeCr, duree, prof, salle,
                          public, tab, uuid, jour, heure)
    nom = "s" * string(numSemaine) * ".csv"
    df = DataFrame(semaine = [numSemaine], jour = [jour],  matiere = [matiere],
                   typeCr = [typeCr], numApogee = "numApogee", heure = [heure],
                   duree = [duree], professeur = [prof], salleDeCours = [salle],
                   public = [public], tab = [tab], uuid = [uuid])
    CSV.write(REPERTOIRE_SEM * SEP * nom, df,
              header = false, append = true, delim=';')
end

#= Supprime le CSV previsionnel et le répertoire des csv calculés, s'il existe,
   puis crée un nouveau CSV prévisionnel 'vide' et un nouveau dossier qui
   contiendra les CSV calculés. =#
function deleteAndCreateCSVcreneau(numSemaine)
    nomCSVPrev = "s" * string(numSemaine) * ".csv"
    try
        # Suppression du fichier CSV prévisionnel
        rm(REPERTOIRE_SEM * SEP * nomCSVPrev)
    catch e
        print(e)
    end
    touch(REPERTOIRE_SEM * SEP * nomCSVPrev)   # crée un CSV vide
    try
        # Suppression du répertoire des CSV calculés pour la semaine désignée
        rm(REPERTOIRE_PLAN * SEP * string(numSemaine), recursive=true)
    catch e
        print(e)
    end
    try
        # Création du répertoire des CSV calculés pour la semaine désignée
        mkdir(REPERTOIRE_PLAN * SEP * string(numSemaine))
    catch e
        print(e)
    end
end

#= Fonction qui insère un créneau dans la base de données avec :
son identifiant, numéro de semaine, onglet, type de cours, nom de matière, prof,
liste de salles possibles, groupe d'étudiants, duree en quart d'heure, nom du
jour, horaire, salle finalement retenue =#
function insereCreneauBDD(id, ns, tab, type, nm, pr, s, gr, duree, ndj="", h="", sR="")
    if id == "???"
        # Provient forcément de l'import ExcelToBDD
        id = string(uuid1())                 # donc fabrique un uuid
    end
    req = """ INSERT INTO previsionnelEDT VALUES("$id", $ns, "$tab", "$type",
          "$nm", "$pr", "$s", "$gr", $duree, "$ndj", "$h", "$sR") """
    
    DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req)
end

#= Fonction qui supprime un créneau de la base de données =#
function supprimeCreneauBDD(id)
    req = """ DELETE FROM previsionnelEDT where uuid = "$id" """
    DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req)
end

#= Fonction qui met à jour un créneau dans la base de données avec :
son identifiant, numéro de semaine, onglet, type de cours, nom de matière, prof,
liste de salles possibles, groupe d'étudiants, duree en quart d'heure, nom du
jour, horaire, salle finalement retenue =#
function updateCreneauBDD(id, ns, tab, type, nm, pr, s, gr, duree, ndj="", h="", sR="")
    req = """ UPDATE previsionnelEDT SET numSemaine=$ns, tab="$tab",
                     typeDeCours="$type", nomModule="$nm", prof="$pr",
                     salles="$s", groupe="$gr", dureeEnMin=$duree,
                     nomDuJour="$ndj", horaire="$h", salleRetenue="$sR"
              WHERE uuid="$id" """
    DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req)
end

#= Fonction qui met à jour un créneau FORCE dans la base de données =#
function updateCreneauForceBDD(id, ndj, h, sR)
    req = """ UPDATE previsionnelEDT
              SET nomDuJour="$ndj", horaire="$h", salleRetenue="$sR"
              WHERE uuid="$id" """
    DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req)
end

#= Fonction qui déplace un créneau (son 'tab' change) dans la base de données =#
function moveCreneauBDD(id, tab, numSemaine)
    req = """ UPDATE previsionnelEDT SET tab="$tab", numSemaine=$numSemaine
              WHERE uuid="$id" """
    DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req)
end

#= Fonction qui lit tous les créneaux d'une semaine précisée plus tous les
   créneaux de la corbeille dans la base de données =#
function selectCreneauxBDD(numSemaine)
    r = """ select * from previsionnelEDT
            WHERE (numSemaine="$numSemaine" or tab="corbeille") """
    df = DataFrame(DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), r))
    return df
end 

#= Fonction qui affiche les données de la table =#
function afficheDonnees()
    r = """ select * from previsionnelEDT """
    df = DataFrame(DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), r))
    println(df)
end

# Vérifie l'existence d'UNE SEULE salle à la fois
function checkExistanceSalle(salle)
    req = """ select nomSalle from salles """
    df = DataFrame(DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req))
    return salle in df.nomSalle ? "true" : "false"
end

# Vérifie l'existence d'un prof
function checkExistanceProf(prof)
    req = """ select nomProf from professeurs """
    df = DataFrame(DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req))
    return prof in df.nomProf ? "true" : "false"
end

# Insere un prof depuis le moteur
function insereProfdepuisMoteur(nomProf)
    req = """ INSERT INTO professeurs VALUES("$nomProf") """
    try
        DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), req) 
    catch e
    end
end

#= Fonction qui récupère les données de la table prof =#
function selectDonneesprof()
    r = """ select * from professeurs ORDER BY nomProf"""
    df = DataFrame(DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), r))
    return df
end

# Fonction qui récupère les données de la table des salles
function selectDonneesSalles()
    r = """ select * from salles ORDER BY nomSalle"""
    df = DataFrame(DBInterface.execute(SQLite.DB(NOM_DATABASE_EDT), r))
    return df
end

### PROGRAMME PRINCIPAL
# ----> Création de la table au départ après avoir effacé le fichier
# (puis commenter les deux lignes suivantes) 
#creeFichierEtTableBDD()
#creeFichierEtTableProf()
#checkExistanceSalle("C2")

# POUR VIDER BASE ET DONNEES INTERNE !!!
# NE SURTOUT PAS LANCER LE SERVEUR SI LA LIGNE CI-DESSOUS N'EST PAS EN COMMENTAIRE !
#viderToutesInfos()