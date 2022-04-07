function ValiderAjouterprof(){
	if($('#Txt').val() != null){
		var nom = $('#Txt').val().charAt(0).toUpperCase() + $('#Txt').val().slice(1).toLowerCase();
	var url = "http://localhost:8000/ajoutProf?nomProf="+ nom;
	$.ajax({url: url});
	alert("La personne a été ajouté");
	}else{
		alert("La zone ne doit pas être vide");
		return;
	}
}