// Fichier Javascript/Jquery pour gérer l'aspect dynamique des plannings
// du projet EDTAutomatic (moteur de recuit simulé écrit en Julia)
// Auteur : Philippe Belhomme
// Date de modification : vendredi 21 janvier 2022

// Variables globales
var NBJOURS = 0;
var NBCRENEAUX = 0;

// Fonction appelée quand la page web est entièrement chargée
$(document).ready(function() {
    // Requête AJAX en jquery : récupère HEUREDEB et NBCRENEAUX
    $.getJSON( "http://localhost:8000/constantes", function( data ) {
        /*$.each( data, function( key, val ) {
            console.log( key + ":" + val );
        });*/

        // Cache par défaut le bouton "VALIDER"
        $("#btValider").hide();

        // Affecte des valeurs aux variables globales
        NBJOURS = parseInt(data["NBJOURS"]);
        NBCRENEAUX = parseInt(data["NBCRENEAUX"]);
        
        /* Construction dynamique de la suite du tableau de planning (après la
           ligne d'en-tête). Chaque créneau possèdera un numéro entre 1 et 210.
           numéro 1 pour le lundi 8h, 2 pour mardi 8h... 5 pour vendredi 8h,
           6 pour lundi 8h15... et 210 pour vendredi 18h15. */
        var codeSup = "";
        var numCreneau = 1;
        for (var ligne=0; ligne<data["NBCRENEAUX"]; ligne++) {
            codeSup += "<tr>";
            for (var colonne=1; colonne<=6; colonne++) {
                if (colonne == 1) {
                    // Colonne de gauche donc position des heures
                    codeSup += "<td class='horaire' data-row='" + ligne + "'>";
                    var heure = Math.floor(ligne/4) + 8 ;
                    if (heure < 10) {
                        heure = "0" + heure.toString();
                    }
                    var minute = (ligne % 4) * 15;
                    if (minute == 0) {
                        minute = "00";
                    }
                    codeSup += heure.toString() + ":" + minute.toString();
                }
                else {
                    // Autres colonnes, donc cellules pour les créneaux
                    codeSup += "<td class='creneau' data-numcreneau=";
                    codeSup += "'" +  numCreneau.toString() + "'" + ">";
                    numCreneau++;
                }
                codeSup += "</td>";
            }
            codeSup += "</tr>";
        }
        $(entete).after(codeSup);
    });

    // Règle appliquée à tous les <td> de classe 'creneau' pour afficher leur
    // état occupé/non occupé quand on clique sur le bouton 'Remplir planning'.
    function remplirPlanning() {
        // Cache par défaut le bouton "VALIDER"
        $("#btValider").hide();
        // Récupération du nom de la ressource (ex : belhomme)
        // et du numéro de semaine (ex : 38) SOUS FORME de String
        var laRessource = $('#laRessource').val().trim();  // sans espaces !
        var laSemaine = $('#laSemaine').val();
        if (laRessource == "" || laSemaine == "" ) {
            return   // on quitte la fonction
        }
        // Récupère un tableau complet de l'état des N créneaux (ici N=210)
        var url = "http://localhost:8000/lectureDesCreneaux";
        url += '?ressource=' + laRessource + '&semaine=' + laSemaine;
        $.getJSON(url, function(data) {
            // On s'attend à recevoir un tableau des N états de créneaux, sinon "erreur"
            $(".creneau").each(function () {
                var objet = $(this);     // pour garder sa trace
                if (data["etat"] != 'erreur') {
                    // On efface le texte et certaines classes de la cellule
                    objet.text("");
                    objet.removeClass('erreur');
                    objet.removeClass('marque');
                    var numCreneau = objet.data("numcreneau");
                    if (! data["etat"][numCreneau]) {
                        objet.addClass('marque');
                    }
                }
                else {
                    // On positionne tous les créneaux en mode erreur
                    objet.addClass('erreur');
                    objet.text("!");
                }
            }); 
        });
    }

    $('#btRemplissage').on('click', function(e){
        remplirPlanning();
    });

    // Evènement sur créneau (entrée de souris + touche SHIFT enfoncée)
    $('#planningRessource').on('mouseenter', '.creneau', function(e) {
        if (e.shiftKey) {
            // Change l'état du créneau en jouant sur la classe .marque
            $(this).toggleClass('marque');
            // Montre à nouveau le bouton "VALIDER"
            $("#btValider").show();
        }
    });

    // VALIDE tous les créneaux en passant leur état à une fonction Julia (via
    // un endpoint d'API) qui modifiera physiquement le fichier planning sur le
    // disque (sérialisation). On ne passe que les créneaux "occupés" / false.
    $('#btValider').on('click', function(e) {
        // Cache le bouton "VALIDER"
        $("#btValider").hide();
        // Récupération du nom de la ressource et du numéro de semaine
        var laRessource = $('#laRessource').val().trim();
        var laSemaine = $('#laSemaine').val();
        // Crée un objet JSON vide pour l'instant
        jsonObj = [];
        // Balaye tous les créneaux (les cellules du tableau) et ne va stocker
        // que ceux qui sont marqués comme "occupé"
        $(".creneau").each(function () {
            if ($(this).hasClass("marque")) {
                jsonObj.push($(this).data("numcreneau"));
            }
        });
        // Requête AJAX pour envoyer les numéros de créneaux occupés seulement
        var url = "http://localhost:8000/affecteLesCreneaux";
        url += '?ressource=' + laRessource + '&semaine=' + laSemaine;
        url += '&liste=' + jsonObj.toString();
        $.ajax({url: url});
    });

    // Gère les changements de valeur pour "ressource" et "semaine"
    $("#laSemaine, #laRessource").change(function(e){
        remplirPlanning();
    });

    // Gère les clics sur les noms de jour (CTRL -> occupé SHIFT+CTRL -> libéré)
    $(".nomJour").on("click", function(e) {
        colonne =  parseInt($(this).data("col"));
        for (var i = colonne ; i <= NBJOURS * NBCRENEAUX ; i += NBJOURS) {
            $(".creneau").each(function () {
                if ($(this).data("numcreneau") == i) {
                    if (e.ctrlKey && !e.shiftKey) {
                        $(this).addClass('marque');
                        $("#btValider").show();
                    }
                    if (e.ctrlKey && e.shiftKey) {
                        $(this).removeClass('marque');
                        $("#btValider").show();
                    }
                }
            });
        }
    });

    // Gère les mousedown sur les horaires (CTRL -> occupé SHIFT+CTRL -> libéré)
    $('#planningRessource').on('mouseenter', '.horaire', function(e) {
        var ligne =  parseInt($(this).data("row"));
        var debut = ligne * NBJOURS + 1;
        for (var i = debut ; i < debut + NBJOURS ; i++) {
            $(".creneau").each(function () {
                if ($(this).data("numcreneau") == i) {
                    if (e.ctrlKey && !e.shiftKey) {
                        $(this).addClass('marque');
                        $("#btValider").show();
                    }
                    if (e.ctrlKey && e.shiftKey) {
                        $(this).removeClass('marque');
                        $("#btValider").show();
                    }
                }
            });
        }
    });
});
