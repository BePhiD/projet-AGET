// Fichier Javascript/Jquery pour créer les la liste des créneaux d'une semaine
// du projet EDTAutomatic (moteur de recuit simulé écrit en Julia)
// Auteur : Philippe Belhomme (+ Swann Protais pendant son stage de DUT INFO)
// Date de création : lundi 31 janvier 2022 (isolement Covid...)
// Date de modification : dimanche 18 septembre 2022

/* ------------------------
-- Fonctions utilitaires --
-------------------------*/
var salleExiste = "";   // GLOBALE

// Fonction qui fabrique (et retourne) la chaine html d'un créneau
function fabriqueCreneauHTML(uuid, type, matiere, prof, lieu, public, duree, onglet) {
    ch = "<div id='" + uuid + "' class='creneau' ";
    ch += "data-type='" + type + "' data-matiere='" + matiere + "' ";
    ch += "data-prof='" + prof + "' data-lieu='" + lieu + "' ";
    ch += "data-public='" + public + "' data-duree='" + duree + "' ";
    ch += "data-onglet='" + onglet + "'>";
    ch += "<b>" + type + "&nbsp;" + matiere + "</b><br>";
    ch += prof + "<br>" + lieu + "<br>";
    ch += public + "<br>" + duree + "</div>";
    return ch;
}

/* Fonction qui lit les données d'un créneau à partir du formulaire en
   supprimant les espaces inutiles (trim) ; retourne un JSON. */
function attributsFromFormulaire() {
    return {
        "type": $("#type").val().trim(),
        "matiere": $("#matiere").val().trim(),
        "prof": $("#prof").val().trim(),
        "lieu": $("#lieu").val().trim(),
        "public": $("#public").val().trim(),
        "duree": $("#duree").val().trim()
    }
}

// Fonction qui permet de remplir le formulaire avec les données fournies
function remplitFormulaire(type, matiere, prof, lieu, public, duree, uuid) {
    $("#type").val(type);  $("#matiere").val(matiere);  $("#prof").val(prof);
    $("#lieu").val(lieu);  $("#public").val(public);    $("#duree").val(duree);
    $("#uuid").val(uuid);
}

/* Fonction qui lit les attributs d'un créneau à partir de son uuid puis
   retourne un JSON.  */
function attributsFromUUID(uuid) {
    return {
        "type": $("#"+uuid).attr("data-type"),
        "matiere": $("#"+uuid).attr("data-matiere"),
        "prof": $("#"+uuid).attr("data-prof"),
        "lieu": $("#"+uuid).attr("data-lieu"),
        "public": $("#"+uuid).attr("data-public"),
        "duree": $("#"+uuid).attr("data-duree"),
        "onglet": $("#"+uuid).attr("data-onglet")
    }
}

// Fonction qui fabrique un JSON à partir des infos d'un créneau (son uuid)
function fromAttrToJSON(numeroSemaine, nomOnglet, uuid) {
    return {
        week: numeroSemaine,
        tab: nomOnglet,
        uuid: uuid,
        data: attributsFromUUID(uuid)       // donc de type JSON
    };
}

// Fonction qui permet de colorer les créneaux selon leur type (CM/TD/TP)
function colore_CM_TD_TP(uuid, typeDeCours) {
    switch (typeDeCours) {
        case 'CM':
            $("#"+uuid).addClass("CM");     // il acquiert la classe CM
            $("#"+uuid).removeClass("TD");  // et perd les autres
            $("#"+uuid).removeClass("TP");
            $("#"+uuid).removeClass("Autre");
            break;
        case 'TD':
            $("#"+uuid).addClass("TD");     // il acquiert la classe TD
            $("#"+uuid).removeClass("CM");  // et perd les autres
            $("#"+uuid).removeClass("TP");
            $("#"+uuid).removeClass("Autre");
            break;
        case 'TP':
            $("#"+uuid).addClass("TP");     // il acquiert la classe TP
            $("#"+uuid).removeClass("CM");  // et perd les autres
            $("#"+uuid).removeClass("TD");
            $("#"+uuid).removeClass("Autre");
            break;
        default:
            $("#"+uuid).addClass("Autre");  // il acquiert la classe Autre
            $("#"+uuid).removeClass("CM");  // et perd les autres
            $("#"+uuid).removeClass("TD");
            $("#"+uuid).removeClass("TP");
    }
}

/* Fonction activée après le 'drop' d'un créneau, compatible corbeille/onglets.
   Mais cette fonction peut également être appelée quand on demande à DEPLACER
   tous les créneaux d'un onglet vers la corbeille ou vice-versa. Dans ce cas la
   variable 'ui' ne sera pas générée par un événement mais servira à recevoir
   l'uuid du créneau en cours de déplacement (ASTUCE : voir si la longueur de
   cette variable est 36 !). */
function dropCreneau(event, ui, idZoneDuDrop) {
    /* Si la zone d'arrivée est le prévisionnel, positionne la zone sur
       l'onglet actif et retrouve son nom pour la sauvegarde en BDD */
    var idZoneDuDropOrigine = idZoneDuDrop;    // pour garder une trace
    if (idZoneDuDrop == "#previsionnel") {
        // Recherche le numéro de l'onglet actif (commence à 0)
        var numeroOnglet = $("#previsionnel").tabs("option", "active");
        idZoneDuDrop = "#previsionnel-" + numeroOnglet;
        // Recherche le nom de l'onglet actif
        var nomOnglet = $("#previsionnel a")[numeroOnglet].text;
    }
    else {
        var nomOnglet = "corbeille";
    }
    // Récupère l'identifiant du créneau déplacé dans 'ui'...
    if (ui.length == 36) {
        var uuid = ui;                   // vient d'un déplacement en masse
    }
    else {
        var uuid = ui.draggable[0].id;   // vient d'un 'drop' à la souris
    }

    var dropEnBloc = false;
    if ($("#"+uuid).hasClass("selectionMultiple")) {
        var dropEnBloc = true;
    }
    // Le déplace dans la bonne zone (mais il est mal positionné, en vrac...)
    $("#"+uuid).appendTo(idZoneDuDrop);
    // Récupère les informations du créneau depuis son uuid
    let {type, matiere, prof, lieu, public, duree, onglet} = attributsFromUUID(uuid);
    // Mais 'onglet' est l'ancienne position du créneau ; doit être mis à jour
    onglet = nomOnglet
    // Enregistre le nom de l'onglet dans l'un des attributs du créneau
    $("#"+uuid).attr("data-onglet", onglet);
    // Construit le code du <div> qui sera injecté dans la zone d'arrivée
    ch = fabriqueCreneauHTML(uuid, type, matiere, prof, lieu, public, duree, onglet);
    // Supprime le créneau mal positionné de sa zone dans le DOM...
    $("#"+uuid).remove();
    // ...puis le réinjecte, mais cette fois il a une position correcte
    $(idZoneDuDrop).append(ch);
    // Rend cet élément du DOM à nouveau "draggable"
    $("#"+uuid).draggable({
        opacity: 0.5,
        revert: "invalid"        // retour à sa position si zone non dropable
    });
    // Lui donne la classe "corbeille" s'il se trouve dedans, sinon la retire
    if (idZoneDuDrop == "#corbeille") {
        $("#"+uuid).addClass('corbeille');
    }
    else {
        $("#"+uuid).removeClass('corbeille');
    }
    // Colore le créneau selon son type de cours
    colore_CM_TD_TP(uuid, type);
    // Réenregistre ce créneau dans la BDD via un appel à une API julia (UPDATE)
    var numeroSemaine = $("#laSemaine").val();
    // Requête AJAX pour déplacer le créneau (onglet <--> corbeille)
    var url = "http://localhost:8000/moveCreneau?creneau=" + uuid;
    url += "&zone=" + nomOnglet + "&numSemaine=" + numeroSemaine;
    $.ajax({url: url});

    /* Voir si le 'drop' provenait d'un créneau "multi-sélectionné" et dans ce
       cas l'appliquer aussi à tous ses collègues. */
    if (dropEnBloc) {
        /* ...retirer la classe 'selectionMultiple' à ce créneau (pour ne pas
           le reprendre en compte)  */
        //$("#"+uuid).removeClass('selectionMultiple');
        /* ...balayer tous les créneaux qui ont la classe 'selectionMultiple'
           dans la même zone d'origine  */
        $(idZoneDuDropOrigine + " .creneau,.selectionMultiple").each(function () {
            // ...retirer la classe 'selectionMultiple' à ce créneau et...
            var nodeMap = $(this)[0].attributes;
            var uuid = nodeMap.getNamedItem("id").value;
            $("#"+uuid).removeClass('selectionMultiple');
            // ...appeler de manière récursive cette fonction dans la même zone
            dropCreneau("", uuid, idZoneDuDropOrigine);
        });
    }
    compteNombreDeCreneauxParType();   // Réaffiche les infos actualisées
}

// Fonction qui fabrique un nouveau créneau à partir des infos du formulaire
function fabriqueCreneauFromFormulaire() {
    // Récupère les informations du créneau (vérifie si oubli...)
    let {type, matiere, prof, lieu, public, duree} = attributsFromFormulaire();
    if (type == "" || matiere == "" || prof == "" ||
        lieu == "" || public == ""  || duree == "") {
        alert("Il manque des informations !");
        return;
    }
    
    /* Lance une fonction asynchrone pour tester l'existence des salles...
       PAS FACILE ! Construit la liste des salles qui n'existent pas et
       l'affiche dans une alert. */
    verifieSiSallesExistent(lieu).then(function() {
        // Transforme la chaîne de caractères retournée en objet JSON
        obj_JSON = JSON.parse(salleExiste)
        sallesAvecProbleme = ""
        for (var i=0; i<obj_JSON.length; i++) {
            // Extrait le nom de la salle
            var salle = Object.keys(obj_JSON[i]);
            // Extrait l'état possible ('true') ou non ('false') ; donc String
            var estPossible = obj_JSON[i][Object.keys(obj_JSON[i])];
            // Teste la chaîne de caractères (ce n'est pas un booléen !)
            if (estPossible == 'false') {
                if (sallesAvecProbleme.length == 0) {   // première salle
                    sallesAvecProbleme += salle;
                }
                else {
                    sallesAvecProbleme += ',' + salle;  // ajoute une ','
                }
            }
        }
        if (sallesAvecProbleme.length == 0) {
            // On peut créer le créneau car les salles existent
            creeCreneau(type.toUpperCase(), matiere, prof,
                        lieu.toUpperCase(), public.toUpperCase(), duree);
        } else {
            alert("PROBLEME ! Salle(s) inconnue(s) : " + sallesAvecProbleme);
        }
    });
}

/* Fonction (Swann/PB) qui vérifie si les salles listées existent. Elle est en
   mode asynchrone, basée sur une 'Promise' ; pas très simple... */
async function verifieSiSallesExistent(lieu) {
    let myPromise = new Promise(function(resolve) {
        // Récupère les noms de salles (sans espaces) séparés par des ','
        const salles = lieu.toUpperCase().replace(/ /g,'').split(',');
        var url = "http://localhost:8000/checkSalle?nomSalle=" + salles;
        setTimeout(() => resolve($.getJSON(url, function(data) {
            return JSON.parse(data);       // récupère l'objet JSON
        })), 700);
    });
    salleExiste = await myPromise;
}

// Fonction qui remplit la liste déroulante des profs
function afficherProf() {
    var url = "http://localhost:8000/selectProf";
    $.getJSON( url, function(data) {
        // Récupère l'objet JSON (en fait un tableau de JSON)
        // Mais s'il est vide la chaîne retournée est ']' ; donc quitter !
        if (data == "]") {
            return;
        }
        obj = JSON.parse(data);
        // Balaye tous les éléments du tableau
        for (var i = 0; i<obj.length; i++) {
            var nomProf = obj[i]["nomProf"];
            // Construit le code du <div> qui sera injecté dans la zone du prévisionnel
            ch = fabriqueListeProf(nomProf);
        }
    });
}

// Fonction qui insère chaque prof dans une liste déroulante
function fabriqueListeProf(nomProf) {
    var select = document.getElementById("prof");
    var opt = document.createElement("option");
    opt.textContent = nomProf;
    opt.value = nomProf;
    select.appendChild(opt);
}

// Fonction qui remplit la liste déroulante des publics
function afficherPublic() {
    var url = "http://localhost:8000/selectPublic";
    $.getJSON( url, function(data) {
        // Récupère l'objet JSON (en fait un tableau de JSON)
        // Mais s'il est vide la chaîne retournée est ']' ; donc quitter !
        if (data == "]") {
            return;
        }
        obj = JSON.parse(data);
        // Balaye tous les éléments du tableau
        for (var i = 0; i<obj.length; i++) {
            var groupes = obj[i]["groupes"];
            // Construit le code du <div> qui sera injecté dans la zone du prévisionnel
            ch = fabriqueListePublic(groupes);
        }
    }); 
}

// Fonction qui insère chaque public dans la liste
function fabriqueListePublic(groupes){
    var select = document.getElementById("public");
    var opt = document.createElement("option");
    opt.textContent = groupes;
    opt.value = groupes;
    select.appendChild(opt);
}

/* Fonction qui crée un objet <div> associé au nouveau créneau. Le paramètre
   zone sert à savoir si la duplication s'est faite dans la corbeille ou pas */
function creeCreneau(type, matiere, prof, lieu, public, duree, zone="") {
    // Génère un UUID de 36 caractères pour identifier ce nouveau créneau
    var uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8);
        return v.toString(16);
    });
    // Vérifie si la création se fait dans le prévisionnel (quand zone == ""),
    // sinon zone devrait forcément être "#corbeille".
    if (zone == "") {
        // Recherche le numéro de l'onglet actif
        var numeroOnglet = $("#previsionnel").tabs("option", "active");
        zone = "#previsionnel-" + numeroOnglet;
        // Recherche le nom de l'onglet actif
        var nomOnglet = $("#previsionnel a")[numeroOnglet].text;
    }
    // Construit le code du <div> qui sera injecté dans la zone du prévisionnel
    ch = fabriqueCreneauHTML(uuid, type, matiere, prof, lieu, public, duree, nomOnglet);
    // Ajoute le créneau au bon endroit (onglet ou corbeille)
    $(zone).append(ch);
    if (zone == "#corbeille") {        // il a été dupliqué depuis la corbeille
        $("#"+uuid).addClass("corbeille");   // il acquiert la classe corbeille
        var nomOnglet = "corbeille";         // et on retient son nom
    }
    // Rend ce nouvel élément du DOM "draggable"
    $("#"+uuid).draggable({ 
        opacity: 0.5,
        revert: "invalid"
    });
    // Enregistre le nom de l'onglet dans l'un des attributs du créneau
    $("#"+uuid).attr("data-onglet", nomOnglet);
    // Sauvegarde ce créneau dans la BDD via un appel à une API julia
    numeroSemaine = $("#laSemaine").val();
    jsonObj = fromAttrToJSON(numeroSemaine, nomOnglet, uuid);
    // Colore le créneau selon son type de cours
    colore_CM_TD_TP(uuid, type);
    compteNombreDeCreneauxParType();   // Réaffiche les infos actualisées
    // Requête AJAX pour envoyer le créneau à sauvegarder
    var url = "http://localhost:8000/insertCreneau?creneau=";
    url += JSON.stringify(jsonObj);
    $.ajax({url: url}).done(function() {
        // TODO: réactiver le bouton Créer (ou sa callback)
    });
}

/* Fonction qui retourne le nombre de créneau de l'onglet courant par type */
function compteNombreDeCreneauxParType() {
    var nb_CM = 0;
    var nb_TD = 0;
    var nb_TP = 0;
    var nb_Autres = 0;

    // Recherche le numéro de l'onglet actif (commence à 0)
    var numeroOnglet = $("#previsionnel").tabs("option", "active");
    // En déduit l'élément racine du DOM
    idZoneCourante = "#previsionnel-" + numeroOnglet;
    /* Utilise la fonction 'creeCreneau' sur chaque créneau de l'onglet */
    $(idZoneCourante + " .creneau").each(function () {
        var nodeMap = $(this)[0].attributes;
        var uuid = nodeMap.getNamedItem("id").value;
        let {type, matiere, prof, lieu, public, duree} = attributsFromUUID(uuid);

        // Compte le nombre de créneaux du planning en cours, par type
        if (type.toUpperCase() == "CM") {
            nb_CM += 1;
        }
        else if (type.toUpperCase() == "TD") {
            nb_TD += 1;
        }
        else if (type.toUpperCase() == "TP") {
            nb_TP += 1;
        }
        else {
            nb_Autres += 1;
        }
    });

    var total = nb_CM + nb_TD + nb_TP + nb_Autres;
    var txt = String(total);
    if (total > 0) {
        txt += '  [CM : ' + nb_CM + '  /  TD : ' + nb_TD + '  /  TP : ';
        txt += nb_TP + '  /  Autre : ' + nb_Autres + ']';
    }

    $("#infoNombreDeCreneaux").text(txt);
}

/* -------------------------------------------------------------
-- Fonction appelée quand la page web est entièrement chargée --
--------------------------------------------------------------*/
$(document).ready(function() {
    //TODO: test pour ajouter un onglet "dynamiquement"
    /*optionText = "GIM-3A-FI";
    optionHREF = "#previsionnel-2";
    optionDIV  = "previsionnel-2";
    $('#dep').append(`<li><a href="${optionHREF}">${optionText}</a></li>`);
    $('#previsionnel').append(`<div id="${optionDIV}"></div>`);*/

    // Désactive tous les éléments du formulaire par défaut et le bouton '+'
    $("#formulaire").children().hide();
    afficherProf();
    afficherPublic();
    
    // Permet de mettre en oeuvre le système d'onglets de jquery-ui
    $("#previsionnel").tabs();
    // Rend la corbeille "droppable"
    $("#corbeille").droppable({
        accept: ".creneau",         // la corbeille n'accepte que des créneaux
        drop: function(event, ui) {
            dropCreneau(event, ui, "#corbeille");
        }
    });
    // Rend le système de tabs "droppable" (tous les onglets seront impactés)
    $("#previsionnel").droppable({
        accept: ".corbeille",         // que ceux venant de la corbeille
        drop: function(event, ui) {
            dropCreneau(event, ui, "#previsionnel");
        } 
    });
    
    // Charge dans l'espace de travail les créneaux prévus cette semaine là
    remplirCreneaux();

    // Gère le bouton '+' pour ajouter un créneau
	if ($("#laSemaine").val() > 0 && $("#laSemaine").val() < 53) {
    	$('#btAjoutCreneau').show(); 
    }
    else {
    	$('#btAjoutCreneau').hide();
    }
    // Action après saisie/changement de numéro de semaine
    $("#laSemaine").on("change", function() {
    	remplirCreneaux();            // charge les créneaux prévus
    	if ($("#laSemaine").val() > 0 && $("#laSemaine").val() < 53) {
    		$('#btAjoutCreneau').show(); 
    	} else {
    		$('#btAjoutCreneau').hide();
    	}
    });

    /* Fonction qui remplit les onglets avec les créneaux prévus pour la semaine
       en cours. Permet de 'ré-initialiser' l'affichage si nécessaire. */
    function remplirCreneaux() {
        // Efface tous les éléments du DOM qui ont la classe 'creneau'
        $(".creneau").each(function () {
            var obj = $(this)[0];
            obj.remove();
        });
        $('#btAjoutCreneau').hide();         // cache le bouton '+'
        var numeroSemaine = $("#laSemaine").val();
        // Requête AJAX pour charger les créneaux de la semaine choisie
        var url = "http://localhost:8000/selectCreneaux?semaine="+numeroSemaine;
        $.getJSON( url, function(data) {
            // Récupère l'objet JSON (en fait un tableau de JSON)
            // Mais s'il est vide la chaîne retournée est ']' ; donc quitter !
            if (data == "]") {
                return;
            }
            obj = JSON.parse(data);
            /* Balaye tous les éléments du tableau */
            for (var i = 0; i<obj.length; i++) {
                var uuid = obj[i]["uuid"];
                var typeDeCours = obj[i]["typeDeCours"];
                var nomModule = obj[i]["nomModule"];
                var prof = obj[i]["prof"];
                var salles = obj[i]["salles"];
                var groupe = obj[i]["groupe"];
                var dureeEnMin = obj[i]["dureeEnMin"];
                var tab = obj[i]["tab"];
                // Code du <div> qui sera injecté dans la zone du prévisionnel
                ch = fabriqueCreneauHTML(uuid, typeDeCours, nomModule, prof,
                                        salles, groupe, dureeEnMin, tab);
                // Détermine dans quelle zone il va falloir insérer le créneau
                if (tab == "corbeille") {
                    var zone = "#corbeille";
                }
                else {
                    // En fonction de la valeur de 'tab' il faudra déterminer
                    // dans quel onglet le créneau doit se placer.
                    for (var t=0; t<$('#previsionnel ul li').length; t++) {
                        if (tab == $("#previsionnel a")[t].text) {
                            var zone = "#previsionnel-" + t;
                        }
                    }
                }
                // Ajoute le créneau au bon endroit (onglet ou corbeille)
                $(zone).append(ch);
                if (zone == "#corbeille") {     // il appartenait à la corbeille
                    $("#"+uuid).addClass("corbeille");  // il acquiert sa classe
                }
                else {
                    $("#"+uuid).removeClass("corbeille"); // sinon la retire
                }
                // Rend ce nouvel élément du DOM "draggable"
                $("#"+uuid).draggable({
                    opacity: 0.5,
                    revert: "invalid"
                });
                // Colore les créneaux selon leur type de cours
                colore_CM_TD_TP(uuid, typeDeCours);
            }
            /* En plaçant cette ligne ici le bouton '+' ne sera montré que
               lorsque la requête AJAX (qui est asynchrone) sera terminée. */
            $('#btAjoutCreneau').show();         // montre le bouton '+'

            // Affiche le nombre de créneaux par type de l'onglet actif
            compteNombreDeCreneauxParType();
        });
    }

    // Action quand on clique sur un onglet : compter le nombre de créneaux
    $("#dep").on("click", function() {
        compteNombreDeCreneauxParType();
    });

    // Permet de créer le CSV prévisionnel quand on appuie sur le bon bouton
    $("#makeCSV").on("click", function() {
        // Gestion de l'existence du fichier CSV (suppression/recréation)
        numSemaine = $("#laSemaine").val().toString();
        var url2 = "http://localhost:8000/deleteAndCreateCSV?numSemaine=" + numSemaine; 
        $.ajax({url: url2});
        // Gestion des créneaux qui seront inscrits dans le CSV, donc tous SAUF
        // ceux qui sont actuellement dans la corbeille.
        var url = "http://localhost:8000/selectCreneaux?semaine=" + numSemaine;
        $.getJSON( url, function( data ) {
            // Récupère l'objet JSON (en fait un tableau de JSON)
            // Mais s'il est vide la chaîne retournée est ']' ; donc quitter !
            if (data == "]") {
                return;
            }
            obj = JSON.parse(data);
            // Balaye tous les éléments du tableau
            for (var i = 0; i<obj.length; i++) {
                var uuid = obj[i]["uuid"];
                var typeDeCours = obj[i]["typeDeCours"];
                var nomModule = obj[i]["nomModule"];
                var prof = obj[i]["prof"];
                var salles = obj[i]["salles"];
                var groupe = obj[i]["groupe"];
                var dureeEnMin = obj[i]["dureeEnMin"];
                var tab = obj[i]["tab"];
                // Les créneaux hors 'corbeille' seront inscrits dans le CSV
                if (tab != "corbeille") {
                    var url3 = "http://localhost:8000/createCSV?numSemaine=";
                    url3 += numSemaine+"&matiere="+nomModule+"&typeCr=";
                    url3 += typeDeCours+"&duree="+dureeEnMin.toString();
                    url3 += "&professeur="+prof+"&salleDeCours="+salles;
                    url3 += "&public="+groupe.toUpperCase()+"&tab="+tab;
                    url3 += "&uuid="+uuid;
                    $.ajax({url: url3});
                }
            }
        });
        alert("Création du CSV prévisionnel... OK.");
    });

    // Lance le moteur de recuit simulé quand on appuie sur le bon bouton
    $("#lancerMoteurCalcul").on("click", function() {
        numSemaine = $("#laSemaine").val();
        var result = prompt("Nombre de versions d'EDT (max: 10)");
        try {
            if (parseInt(result) <= 10 && parseInt(result) > 0) {
                var url ="http://localhost:8000/lancerMoteur?numSemaine="+numSemaine+"&nbEDTCalcules="+result;
                $.ajax({url: url});
            }
            else {
                alert("La valeur doit être comprise entre 1 et 10 !");
            }
        } catch(e) {
            alert("Il me faut un nombre entre 1 et 10 ! Rien d'autre...");
        }
    });

	/* Permet d'ajouter un prof quand on appuie sur le bon bouton. Le nom aura
       la première lettre en majuscule, les autres en minuscules et chaque
       espace sera remplacé par un tiret. */
    $("#addProf").on("click", function() {
        var result = prompt("Nom de famille du nouvel enseignant ?");
        if(result.trim() != "") {
            var nom = result.charAt(0).toUpperCase() + result.slice(1).toLowerCase();  
            nom = nom.replace(" ", '-');
            var url = "http://localhost:8000/ajouterProf?nomProf=" + nom;
            $.ajax({url: url});
            alert("L'enseignant a bien été ajouté.");
            location.reload();  // recharge la page web pour mettre à jour la liste
        }
        else {
            alert("Vous n'avez saisi aucun nom d'enseignant !!!");
            return;
        }
    });

    // Permet de supprimer un prof quand on appuie sur le bon bouton
    $("#supProf").on("click", function() {
        var myWin = window.open("popupNouveauProf.html", "",
                                "width=600, height=400, top=200, left=360");
    });

    /* Permet d'ajouter une salle quand on appuie sur le bon bouton. Le nom sera
       entièrement en majuscule et chaque espace sera remplacée par un tiret. */
    $("#addSalle").on("click", function() {
        var result = prompt("Nom de la nouvelle salle ?");
        if(result.trim() != "") {
            var nom = result.toUpperCase();  
            nom = nom.replace(" ", '-');
            var url = "http://localhost:8000/ajouterSalle?nomSalle=" + nom;
            $.ajax({url: url});
            alert("La salle a bien été ajoutée.");
            location.reload();  // recharge la page web pour mettre à jour la liste
        }
        else {
            alert("Vous n'avez saisi aucun nom de salle !!!");
            return;
        }
    });

    // Permet de supprimer une salle quand on appuie sur le bon bouton
    $("#supSalle").on("click", function() {
        var myWin = window.open("popupNouvelleSalle.html", "",
                                "width=600, height=400, top=200, left=360");
    });
	
    // Action après clic sur bouton "+" dans la zone de création de créneau
    $('#btAjoutCreneau').on('click', function(e) {
        // Vérifie qu'il y a bien un numéro de semaine entre 1 et 52 sinon sort
        var numSemaine = parseInt($("#laSemaine").val());
        if (isNaN(numSemaine) || numSemaine < 1 || numSemaine > 52) {
            alert("Saisissez un numéro de semaine entre 1 et 52 !");
            return;
        }
        $("#formulaire").children().show();  // montre le formulaire mais...
        $('#btAjoutCreneau').hide();         // cache le bouton '+'
        $('#btModifier').hide();             // et cache le bouton 'Modifier'
    });

    // Action après clic sur bouton "Annuler"
    $('#btAnnuler').on('click', function(e) {
        $("#formulaire").children().hide();
        $('#btAjoutCreneau').show();         // montre le bouton '+'
    });

    // Action après clic sur bouton "Créer"
    $('#btCreer').on('click', function(e) {
        fabriqueCreneauFromFormulaire();
        $('#btModifier').hide();             // désactive le bouton Modifier
    });

    // Action après clic sur bouton "Modifier"
    $('#btModifier').on('click', function(e) {
        // Récupère les nouvelles informations du créneau (vérifie si oubli...)
        let {type, matiere, prof, lieu, public, duree} = attributsFromFormulaire();
        var uuid = $("#uuid").val();         // trim inutile car champ caché
        if (type == "" || matiere == "" || prof == "" ||
            lieu == "" || public == ""  || duree == "") {
            alert("Il manque des informations importantes !");
            return;
        }

        try {
            verifieSiSallesExistent(lieu).then(function () {
                // Transforme la chaîne de caractères retournée en objet JSON
                obj_JSON = JSON.parse(salleExiste)
                sallesAvecProbleme = ""
                for (var i=0; i<obj_JSON.length; i++) {
                    // Extrait le nom de la salle
                    var salle = Object.keys(obj_JSON[i]);
                    // Extrait l'état possible ('true') ou non ('false') ; donc String
                    var estPossible = obj_JSON[i][Object.keys(obj_JSON[i])];
                    // Teste la chaîne de caractères (ce n'est pas un booléen !)
                    if (estPossible == 'false') {
                        if (sallesAvecProbleme.length == 0) {   // première salle
                            sallesAvecProbleme += salle;
                        }
                        else {
                            sallesAvecProbleme += ',' + salle;  // ajoute une ','
                        }
                    }
                }
                if (sallesAvecProbleme.length == 0) {
                    // Colore le créneau selon son type de cours
                    colore_CM_TD_TP(uuid, type);
                    // Fabrique le texte "html" du créneau puis l'affiche (donc sans <div>)
                    ch = "<b>" + type + "&nbsp;" + matiere + "</b><br>";
                    ch += prof + "<br>" + lieu + "<br>";
                    ch += public + "<br>" + duree;
                    $("#"+uuid).html(ch);
                    /* Change tous ses attributs pour qu'ils correspondent aux
                       données, sauf le nom de l'onglet qui restera le même. */
                    $("#"+uuid).attr("data-type", type);
                    $("#"+uuid).attr("data-matiere", matiere);
                    $("#"+uuid).attr("data-prof", prof);
                    $("#"+uuid).attr("data-lieu", lieu);
                    $("#"+uuid).attr("data-public", public);
                    $("#"+uuid).attr("data-duree", duree);
                    // Efface le contenu des champs du formulaire
                    remplitFormulaire("", "", "", "", "", "", "");
                    // Désactive le bouton Modifier et remet le bouton Créer
                    $('#btModifier').hide();
                    $('#btCreer').show();
                    compteNombreDeCreneauxParType();   // Réaffiche les infos actualisées
                    // Ré-enregistre ce créneau via l'appel d'une API julia (UPDATE)
                    var numeroSemaine = $("#laSemaine").val();
                    // La MAJ gardera l'onglet/corbeille inchangé
                    var nomOnglet = $("#"+uuid).attr("data-onglet");
                    var jsonObj = fromAttrToJSON(numeroSemaine, nomOnglet, uuid);
                    // Requête AJAX pour modifier le créneau
                    var url = "http://localhost:8000/updateCreneau?creneau=";
                    url += JSON.stringify(jsonObj);
                    $.ajax({url: url});
                }
                else {
                    alert("PROBLEME ! Salle(s) inconnue(s) : " + sallesAvecProbleme);
                }
            }); 
        }
        catch(e) {
            alert(e);
        }
    });

    // Action après clic gauche dans un créneau du previsionnel ou de la corbeille
    $('#previsionnel, #corbeille').on('click', function (e) {
        /* Retrouve l'uuid du créneau ayant reçu le clic gauche et le place
           dans le champ caché du formulaire (pour le rendre accessible)
           ATTENTION : si on clique dans le titre en gras l'id est VIDE !!!
           Dans ce cas il faudra prendre l'id du parent. */
        var idTrouve = e.target.id;
        if (idTrouve == "") {
            idTrouve = e.target.parentElement.id;
        }

        if (e.ctrlKey) {
            if (idTrouve.length == 36) {   // on a CTRL-cliqué dans un créneau
                // Ajoute/enlève la classe 'sélection multiple' au créneau
                $("#"+idTrouve).toggleClass("selectionMultiple");
            }
        }
        else {  // on a juste cliqué dans le prévisionnel (dans ou hors créneau)
            // Enlève la classe 'sélection multiple' des créneaux concernés
            $("#previsionnel,#corbeille .creneau,.selectionMultiple").each(function () {
                var nodeMap = $(this)[0].attributes;
                var uuid = nodeMap.getNamedItem("id").value;
                $("#"+uuid).removeClass("selectionMultiple");
            });
        }        
    });

    /*----------------------------------------
    -- Actions si clic droit sur un créneau --
    ----------------------------------------*/
    // Trouvé sur le site :
    // https://makitweb.com/custom-right-click-context-menu-with-jquery/
    // Show custom context menu
    $('#previsionnel, #corbeille').on('contextmenu', function (e) {
        // Retrouve l'uuid du créneau ayant reçu le clic droit et le place
        // dans le champ caché du formulaire (pour le rendre accessible)
        // ATTENTION : si on clique dans le titre en gras l'id est VIDE !!!
        // Dans ce cas il faudra prendre l'id du parent
        var idTrouve = e.target.id;
        if (idTrouve == "") {
            idTrouve = e.target.parentElement.id;
        }
        /* Remplit le champ caché 'uuid' avec l'id de l'élément cliqué. Mais du
           coup ce champ caché peut contenir entre autres le texte 'corbeille'
           ou 'prévisionnel'. Cela permettra de savoir d'où vient le clic droit.
        */
        $("#uuid").val(idTrouve);

        if (idTrouve == "previsionnel" || idTrouve == "corbeille") {
            /* Affiche le menu contextuel du clic droit dans une ZONE
            (voir code dans planificationSemaine.html pour la liste des <li>) */
            $(".context-menuZ").toggle(100).css({
                top: e.pageY + 5 + "px",
                left: e.pageX + "px"
            });
        }
        else if (idTrouve.length == 36) {    // c'est bien un uuid de créneau
            /* Affiche le menu contextuel du clic droit dans un CRENEAU
            (voir code dans planificationSemaine.html pour la liste des <li>) */
            $(".context-menu").toggle(100).css({
                top: e.pageY + 5 + "px",
                left: e.pageX + "px"
            });
        }

        // Disable default context menu (OBLIGATOIRE !)
        return false;
    });

    // Cache les context menus après un clic en dehors (sinon restent à l'écran...)
    $(document).on('contextmenu click', function() {
        $(".context-menu").hide();
        $(".context-menuZ").hide();
    });

    // Disable context-menu from custom menu
    $('.context-menu').on('contextmenu', function() {
        return false;
    });
    $('.context-menuZ').on('contextmenu', function() {
        return false;
    });

    /*-----------------------------------------------------------------
    -- Traite l'action du sous-menu après clic droit dans un créneau --
    -----------------------------------------------------------------*/
    $('.context-menu li').click(function(e) {
        // Retrouve l'uuid du créneau cliqué dans le champ caché
        var uuid = $("#uuid").val();
        // Cache le menu contextuel
        $(".context-menu").hide();
        // Récupère le nom de l'action choisie dans le menu contextuel
        var action = $(this).find("span:nth-child(1)").attr("id");
        
        // Demande de suppression du créneau (du DOM en fait)
        if (action == "actionSupprimer") {
            if ($("#"+uuid).hasClass("selectionMultiple")) {
                $("#previsionnel #corbeille .creneau,.selectionMultiple").each(function () {
                    var nodeMap = $(this)[0].attributes;
                    var uuid = nodeMap.getNamedItem("id").value;
                    $("#"+uuid).remove();
                    // Requête AJAX pour supprimer le créneau de la BDD
                    $.ajax({url: "http://localhost:8000/deleteCreneau?creneau="+uuid});
                });
            }
            else {  // le clic droit était dans un créneau non multi-sélctionné
                $("#"+uuid).remove();
                // Requête AJAX pour supprimer le créneau de la BDD
                $.ajax({url: "http://localhost:8000/deleteCreneau?creneau="+uuid});
            }
        }
        
        /* Demande de copie d'un ou plusieurs créneau(x) (ils apparaîtront
        en fin de liste). Ils auront forcément un nouvel uuid.  */
        if (action == "actionDupliquer") {
            if ($("#"+uuid).hasClass("selectionMultiple")) {
                $("#previsionnel #corbeille .creneau,.selectionMultiple").each(function () {
                    var nodeMap = $(this)[0].attributes;
                    var uuid = nodeMap.getNamedItem("id").value;
                    let {type, matiere, prof, lieu, public, duree} = attributsFromUUID(uuid);
                    // Regarde si le 'parent' de l'objet est la corbeille
                    var zone = "";              // valeur par défaut, donc onglet actif
                    if ($("#"+uuid).parent().attr("id") == "corbeille") {
                        zone = "#corbeille";
                    }
                    creeCreneau(type, matiere, prof, lieu, public, duree, zone);
                });
            }
            else {
                let {type, matiere, prof, lieu, public, duree} = attributsFromUUID($("#uuid").val());
                // Regarde si le 'parent' de l'objet est la corbeille
                var zone = "";              // valeur par défaut, donc onglet actif
                if ($("#"+uuid).parent().attr("id") == "corbeille") {
                    zone = "#corbeille";
                }
                creeCreneau(type, matiere, prof, lieu, public, duree, zone);
            }
        }

        // Demande de modification du créneau (via le formulaire).
        if (action == "actionModifier") {
            if ($("#"+uuid).hasClass("selectionMultiple")) {
                alert("Désolé, pas possible sur une sélection multiple...");
            }
            else {
                // Récupère les données du créneau cliqué            
                let {type, matiere, prof, lieu, public, duree} = attributsFromUUID(uuid);
                // (Ré)affiche tous les éléments du formulaire
                $("#formulaire").children().show();
                // Remplit le formulaire avec les données du créneau cliqué
                remplitFormulaire(type, matiere, prof, lieu, public, duree, uuid);
            }
        }

        /* Demande de forçage d'un créneau, c'est à dire lui attribuer dès le
        départ un jour et une salle (si c'est possible bien sûr). */
        if (action == "actionForcer") {
            if ($("#"+uuid).hasClass("selectionMultiple")) {
                alert("Désolé, pas possible sur une sélection multiple...");
            }
            else {
                /* Enregistre l'uuid du créneau dans une variable de session
                afin que la pop-up window puisse le récupérer ensuite. */
                localStorage.setItem("uuidCreneauForce", uuid);
                // Ouvre une fenêtre pop-up pour choisir jour+horaire
                var myWin = window.open("popupForceCreneau.html", "",
                                "width=500, height=300, top=200, left=360");
                // Récupérer les 2 infos (ou possibilité Annuler)
                // Vérifier que prof + groupe + une des salles sont libres
                // Positionner le créneau sur cette position
                // Créer 2 nouveaux attributs data-jour et data-heure
            }
        }

        /* Demande de Déforçage d'un créneau, c'est à dire lui retirer ses
        informations de jour et de salle. */
        if (action == "actionDeforcer") {
            if ($("#"+uuid).hasClass("selectionMultiple")) {
                alert("Désolé, pas possible sur une sélection multiple...");
            }
            else {
            }
        }

        compteNombreDeCreneauxParType();   // Réaffiche les infos actualisées
    });

    /*---------------------------------------------------------------
    -- Traite l'action du sous-menu après clic droit dans une zone --
    ---------------------------------------------------------------*/
    $('.context-menuZ li').click(function(e) {
        /* Retrouve le nom de la zone dans laquelle le clic droit a eu lieu
           depuis le champ caché ; pratique !  */
        var zone = $("#uuid").val();
        // Cache le menu contextuel
        $(".context-menuZ").hide();
        // Récupère le nom de l'action choisie dans le menu contextuel
        var action = $(this).find("span:nth-child(1)").attr("id");

        /* Teste l'action demandée et la zone du clic, pour interdire certaines
           options suivant le contexte  */
        if (action == "actionDeplacerToutVersCorbeille" && zone == "corbeille") {
            alert("Action pas possible dans ce contexte !");
            return;
        }
        if (action == "actionCopierToutVersCorbeille" && zone == "corbeille") {
            alert("Action pas possible dans ce contexte !");
            return;
        }
        if (action == "actionDeplacerDeCorbeilleVersOngletCourant" && zone == "previsionnel") {
            alert("Action pas possible dans ce contexte !");
            return;
        }
        if (action == "actionViderCorbeille" && zone == "previsionnel") {
            alert("Action pas possible dans ce contexte !");
            return;
        }

        // Codes des actions autorisées
        if (action == "actionDeplacerToutVersCorbeille" && zone == "previsionnel") {
            // Recherche le numéro de l'onglet actif (commence à 0)
            var numeroOnglet = $("#previsionnel").tabs("option", "active");
            // En déduit l'élément racine du DOM
            idZoneDuClic = "#previsionnel-" + numeroOnglet;
            /* Utilise la fonction 'dropCreneau' sur chaque créneau de l'onglet */
            $(idZoneDuClic + " .creneau").each(function () {
                var nodeMap = $(this)[0].attributes;
                var uuid = nodeMap.getNamedItem("id").value;
                dropCreneau("", uuid, "#corbeille");
            });
            /* Charge dans l'espace de travail les créneaux de cette semaine là
               donc permet de réinitialiser l'affichage de la page. */
            remplirCreneaux();
            return;
        }
        if (action == "actionDeplacerDeCorbeilleVersOngletCourant" && zone == "corbeille") {
            /* Utilise la fonction 'dropCreneau' sur chaque créneau de la corbeille */
            $("#corbeille .creneau").each(function () {
                var nodeMap = $(this)[0].attributes;
                var uuid = nodeMap.getNamedItem("id").value;
                dropCreneau("", uuid, "#previsionnel");
            });
            /* Charge dans l'espace de travail les créneaux de cette semaine là
               donc permet de réinitialiser l'affichage de la page. */
            remplirCreneaux();
            return;
        }
        if (action == "actionCopierToutVersCorbeille" && zone == "previsionnel") {
            // Recherche le numéro de l'onglet actif (commence à 0)
            var numeroOnglet = $("#previsionnel").tabs("option", "active");
            // En déduit l'élément racine du DOM
            idZoneDuClic = "#previsionnel-" + numeroOnglet;
            /* Utilise la fonction 'creeCreneau' sur chaque créneau de l'onglet */
            $(idZoneDuClic + " .creneau").each(function () {
                var nodeMap = $(this)[0].attributes;
                var uuid = nodeMap.getNamedItem("id").value;
                let {type, matiere, prof, lieu, public, duree} = attributsFromUUID(uuid);
                creeCreneau(type, matiere, prof, lieu, public, duree, "#corbeille");
            });
            /* Charge dans l'espace de travail les créneaux de cette semaine là
               donc permet de réinitialiser l'affichage de la page. */
            remplirCreneaux();
            return;
        }
        if (action == "actionViderCorbeille" && zone == "corbeille") {
            /* Récupère les uuid de tous les créneaux de la corbeille puis
               active le même code que 'actionSupprimer' (quand on clique droit
               dans un seul créneau). */
            $("#corbeille .creneau").each(function () {
                var nodeMap = $(this)[0].attributes;
                var uuid = nodeMap.getNamedItem("id").value;
                $("#"+uuid).remove();
                // Requête AJAX pour supprimer le créneau de la BDD
                $.ajax({url: "http://localhost:8000/deleteCreneau?creneau="+uuid});
            });
            /* Charge dans l'espace de travail les créneaux de cette semaine là
               donc permet de réinitialiser l'affichage de la page. */
            remplirCreneaux();
            return;
        }
    });
});
