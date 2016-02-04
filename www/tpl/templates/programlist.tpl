<a class="btn btn-primary visible-xs collapsed" aria-controls="elenco-programmi" type="button" data-toggle="collapse" data-target="#elenco-programmi" aria-expanded="false">
	<span class="sr-only">Menu</span>
	<span class="icon-bar"></span>
	<span class="icon-bar"></span>
	<span class="icon-bar"></span>
</a>
<div class="collapse visible-md visible-lg visible-sm" id="elenco-programmi">
	<div class="list-group">
		{{#programlist}}
			<a href="programma/visualizza?program={{id_programma}}" class="list-group-item {{active}}">
				<h6 class="list-group-item-heading">{{nome_programma}}</h6>
				<small class="list-group-item-text">{{descrizione_programma}}</small>
			</a>
		{{/programlist}}
		{{^programlist}}
			<a href="#" class="list-group-item">
				<h4 class="list-group-item-heading">Nessun programma</h4>
				<p class="list-group-item-text">Non è stato definito alcun programa</p>
			</a>
		{{/programlist}}
	</div>
</div>
