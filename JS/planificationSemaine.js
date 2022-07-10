// Fichier Javascript/Jquery pour créer les la liste des créneaux d'une semaine
// du projet EDTAutomatic (moteur de recuit simulé écrit en Julia)
// Auteur : Philippe Belhomme (+ Swann Protais pendant son stage de DUT INFO)
// Date de création : lundi 31 janvier 2022 (isolement Covid...)
// Date de modification : dimanche 10 juillet 2022

/* ------------------------
-- Fonctions utilitaires --
-------------------------*/

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

// Fonction qui lit et retourne les données d'un créneau à partir du formulaire
// en supprimant les espaces inutiles (trim)
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

// Fonction qui lit les attributs d'un créneau à partir de son uuid
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
        data: attributsFromUUID(uuid)
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

// Fonction activée après le 'drop' d'un créneau ; compatible corbeille/onglets
function dropCreneau(event, ui, idZoneDuDrop) {
    /* Si la zone d'arrivée est le prévisionnel, positionne la zone sur
       l'onglet actif et retrouve son nom pour la sauvegarde en BDD */
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
    // Récupère l'identifiant du créneau déplacé
    var uuid = ui.draggable[0].id;
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
    // puis le réinjecte dans le DOM, mais cette fois il a une position correcte
    $(idZoneDuDrop).append(ch);
    // Rend cette élément du DOM à nouveau "draggable"
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
    
    try {
        verifClasseExiste(lieu).then(
        setTimeout(function () {
            if (ok == "true") {
                matiere = matiere.charAt(0).toUpperCase() + matiere.slice(1).toLowerCase();
                //prof = prof.charAt(0).toUpperCase() + prof.slice(1).toLowerCase();
                creeCreneau(type.toUpperCase(), matiere, prof,
                            lieu.toUpperCase(), public.toUpperCase(), duree);
                return;
        } else {
            alert("Une ou plusieurs des salles inscrites n'existe(nt) pas !");
        }
        }, 1000)); 
    } catch(e) {
        alert(e);
    }			     
}

async function verifClasseExiste(lieu) {
    const words = lieu.replace(/ /g,'').split(',');
    var i;
    var temp;
    var url;
    ok = false;

    for (i=0; i<words.length; i++) {
        temp = words[i].toUpperCase();
        url = "http://localhost:8000/checkSalle?nomSalle="+temp;
        $.getJSON( url, function( data ) {
        // Récupère l'objet JSON (en fait un tableau de JSON)
        // Mais s'il est vide la chaîne retournée est ']' ; donc quitter !
            if (data == "]") {
                return;
            }
            obj = JSON.parse(data);
        }); 

        // Balaye tous les éléments du tableau
        setTimeout(function () {
            for (var i = 0; i<obj.length; i++) {
                ok = obj[i]["OkOuPasOk"]; 
            }
        }, 500);
    }
    setTimeout(function () {
        return 1;
    }, 700);
}

// Fonction qui remplit la liste des profs
function afficherProf() {
    var url = "http://localhost:8000/selectProf";
    $.getJSON( url, function( data ) {
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

// Fonction qui insère chaque prof dans la liste déroulante
function fabriqueListeProf(nomProf) {
    var select = document.getElementById("prof");
    var el = document.createElement("option");
    el.textContent = nomProf;
    el.value = nomProf;
    select.appendChild(el);
}

// Fonction qui remplit la liste déroulante des salles
function afficherSalles() {
    var url = "http://localhost:8000/selectSalles";
    $.getJSON( url, function( data ) {
        // Récupère l'objet JSON (en fait un tableau de JSON)
        // Mais s'il est vide la chaîne retournée est ']' ; donc quitter !
        if (data == "]") {
            return;
        }
        obj = JSON.parse(data);
        // Balaye tous les éléments du tableau
        for (var i = 0; i<obj.length; i++) {
            var nomSalle = obj[i]["nomSalle"];
            // Construit le code du <div> qui sera injecté dans la zone du prévisionnel
            ch = fabriqueListeSalle(nomSalle);
        }
    }); 
}

// Fonction qui insère chaque salle dans la liste déroulante
function fabriqueListeSalle(nomSalle) {
    var select = document.getElementById("lieu");
    var el = document.createElement("option");
    el.textContent = nomSalle;
    el.value = nomSalle;
    select.appendChild(el);
}

// Fonction qui remplit la liste des publics
function afficherPublic() {
    var url = "http://localhost:8000/selectPublic";
    $.getJSON( url, function( data ) {
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
    var el = document.createElement("option");
    el.textContent = groupes;
    el.value = groupes;
    select.appendChild(el);
}

/* Fonction qui crée un objet <div> associé au nouveau créneau. Le paramètre
   zone sert à savoir si la duplication s'est faite dans la corbeille ou pas */
function creeCreneau(type, matiere, prof, lieu, public, duree, zone="") {
    // Génère un UUID pour identifier ce nouveau créneau
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
    // Requête AJAX pour envoyer le créneau à sauvegarder
    var url = "http://localhost:8000/insertCreneau?creneau=";
    url += JSON.stringify(jsonObj);
    $.ajax({url: url}).done(function() {
        // TODO: réactiver le bouton Créer (ou sa callback)
    });
}

/* -------------------------------------------------------------
-- Fonction appelée quand la page web est entièrement chargée --
--------------------------------------------------------------*/
$(document).ready(function() {
    // Désactive tous les éléments du formulaire par défaut et le bouton '+'
	ok = false;
    $("#formulaire").children().hide();
    afficherProf();
    afficherSalles();
    afficherPublic();
    
    // Permet de mettre en oeuvre le système d'onglets de jquery-ui
    $( "#previsionnel" ).tabs();
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
    	}else{
    		$('#btAjoutCreneau').hide();
    	}
    });

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
        });
    }

    // Permet de créer le CSV prévisionnel quand on appuie sur le bon bouton
    $("#makeCSV").on("click", function() {
        numSemaine = $("#laSemaine").val().toString();
        var url2 = "http://localhost:8000/deleteAndCreateCSV?numSemaine=" + numSemaine; 
        $.ajax({url: url2});
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
                // Code du <div> qui sera injecté dans la zone du prévisionnel
                ch = fabriqueCreneauHTML(uuid, typeDeCours, nomModule, prof,
                                        salles, groupe, dureeEnMin, tab);
                var url3 = "http://localhost:8000/createCsv?numSemaine="+numSemaine+"&matiere="+nomModule+"&typeCr="+typeDeCours+"&duree="+dureeEnMin.toString()+"&professeur="+prof+"&salleDeCours="+salles+"&public="+groupe.toUpperCase()
                $.ajax({url: url3});
            }
        });
        alert("Création du CSV prévisionnel... OK.");
    });

    // Lance le moteur de recuit simulé quand on appuie sur le bon bouton
    $("#lancerMot").on("click", function() {
        numSemaine = $("#laSemaine").val();
        var result = prompt("Nombre de tour(s) souhaité(s) (max: 10):");
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
        var result = prompt("Nom de famille du nouveau professeur ?");
        if(result.trim() != "") {
            var nom = result.charAt(0).toUpperCase() + result.slice(1).toLowerCase();  
            nom = nom.replace(" ", '-');
            var url = "http://localhost:8000/ajouterProf?nomProf=" + nom;
            $.ajax({url: url});
            alert("Le professeur a bien été ajouté.");
            location.reload();  // recharge la page web pour mettre à jour la liste
        }
        else {
            alert("Vous n'avez saisi aucun nom de prof !!!");
            return;
        }
    });

    // Permet de supprimer un prof quand on appuie sur le bon bouton
    $("#supProf").on("click", function() {
        var myWin = window.open("popupNouveauProf.html", "",
                                "width=600, height=400, top=200, left=360");
    });

    /* Permet d'ajouter une salle quand on appuie sur le bon bouton. Le nom sera
       entièrement en majuscule et chaque espace sera remplacé par un tiret. */
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
        $('#btModifier').hide();             // cache le bouton 'Modifier'
    });

    // Action après clic sur bouton "Annuler"
    $('#btAnnuler').on('click', function(e) {
        $("#formulaire").children().hide();
        $('#btAjoutCreneau').show();;        // montre le bouton '+'
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
        var uuid    = $("#uuid").val();         // trim inutile car champ caché
        if (type == "" || matiere == "" || prof == "" ||
            lieu == "" || public == ""  || duree == "") {
            alert("Il manque des informations importantes !")
            return;
        }

        try {
            verifClasseExiste(lieu).then(
            setTimeout(function () {
                if (ok == "true"){
                    matiere = matiere.charAt(0).toUpperCase() + matiere.slice(1).toLowerCase();
                    type = type.toUpperCase();
                    lieu = lieu.toUpperCase();
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
                    alert("Une ou plusieurs des salles inscrites n'existe(nt) pas..." )
                }
            }, 1000)); 
        }
        catch(e) {
            alert(e);
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
        $("#uuid").val(idTrouve);        // remplit le champ caché
        
        // Affiche le menu contextuel (voir code html pour la liste des <li>)
        $(".context-menu").toggle(100).css({
            top: e.pageY + 5 + "px",
            left: e.pageX + "px"
        });
        // Disable default context menu (OBLIGATOIRE !)
        return false;
    });

    // Cache le context menu après un clic en dehors (sinon reste à l'écran...)
    $(document).on('contextmenu click', function() {
        $(".context-menu").hide();
    });

    // Disable context-menu from custom menu
    $('.context-menu').on('contextmenu', function() {
        return false;
    });

    /*-----------------------------------------------------------------
    -- Traite l'action du sous-menu après clic droit dans un créneau --
    -----------------------------------------------------------------*/
    $('.context-menu li').click(function(e) {
        // Retrouve l'uuid du créneau cliqué
        var uuid = $("#uuid").val();
        // Cache le menu contextuel
        $(".context-menu").hide();
        // Récupère le nom de l'action choisie dans le menu contextuel
        var action = $(this).find("span:nth-child(1)").attr("id");
        
        // Demande de suppression du créneau (du DOM en fait)
        if (action == "actionSupprimer") {
            $("#"+uuid).remove();
            // Requête AJAX pour supprimer le créneau de la BDD
            $.ajax({url: "http://localhost:8000/deleteCreneau?creneau="+uuid});
        }
        
        // Demande de copie du créneau (il apparaîtra juste à côté).
        // Ce nouveau créneau aura forcément un nouvel uuid.
        if (action == "actionDupliquer") {
            let {type, matiere, prof, lieu, public, duree} = attributsFromUUID($("#uuid").val());
            // Regarde si le 'parent' de l'objet est la corbeille
            var zone = "";              // valeur par défaut, donc onglet actif
            if ($("#"+uuid).parent().attr("id") == "corbeille") {
                zone = "#corbeille";
            }
            creeCreneau(type, matiere, prof, lieu, public, duree, zone);
        }
        // Demande de modification du créneau (via le formulaire).
        if (action == "actionModifier") {
            // Récupère les données du créneau cliqué            
            let {type, matiere, prof, lieu, public, duree} = attributsFromUUID(uuid);
            // (Ré)affiche tous les éléments du formulaire
            $("#formulaire").children().show();
            // Remplit le formulaire avec les données du créneau cliqué
            remplitFormulaire(type, matiere, prof, lieu, public, duree, uuid);
        }        
    });
});
