<div class="panel panel-default" id="elenco-sensori">
	<div class="panel-heading">
		<h6 class="panel-title">
		    <span>Elenco</span>
			<button id="new-sensor" title="Aggiungi sensore" class="btn btn-xs btn-link pull-right">
				<span class="glyphicon glyphicon-plus"></span>
			</button>
		</h6>
	</div>
	<div class="panel-body">
		<ul class="list-group">
			{% for s in sensori|default([]) %}
				{% set active = s.selected == 'selected' ? 'active' : '' %}
				{% set hidden = s.selected == 'selected' ? '' : 'hidden' %}
				<li class="list-group-item {{active}} seleziona-sensore" data-id="{{s.id_sensore}}">
					{{.nome_sensore}}
					<span class="pull-right sensor-action {{hidden}}">
						<a href="#" title="Modifica sensore" class="bg-primary modifica-sensore">
							<i class="fa fa-pencil-square-o" aria-hidden="true"></i>
						</a>
						<a href="#" title="Elimina sensore" class="bg-primary elimina-programma">
							<i class="fa fa-trash-o" aria-hidden="true"></i>
						</a>
					</span>
				</li>
			{% else %}
				<li class="list-group-item">Nessun sensore definito</li>
			{% endfor %}
		</ul>
	</div>
</div>
<div class="clearfix"></div>