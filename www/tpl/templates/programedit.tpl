<ul id="programmazione-settimanale" class="nav nav-pills nav-stacked col-xs-3 col-sm-3 col-md-3" role="tablist">
	{{#programedit.giorni}}
	<li role="presentation" class="{{active}}">
		<a aria-controls="{{#decorateShortDay}}{{num}}{{/decorateShortDay}}"
			role="tab" data-toggle="tab"
			href="#{{#decorateShortDay}}{{num}}{{/decorateShortDay}}">
			{{#decorateDay}}{{num}}{{/decorateDay}}
		</a>
	</li>
	{{/programedit.giorni}}
</ul>
<div id="programma-giornaliero" class="tab-content col-xs-5 col-sm-5 col-md-7">
	{{#programedit.giorni}}
	<div role="tabpanel" class="tab-pane fade {{#active}}in {{active}}{{/active}}" id="{{#decorateShortDay}}{{num}}{{/decorateShortDay}}">
		<div id="#dettaglio-programma" class="table-responsive">
			<table class="table">
				<caption>Programmazione giornaliera</caption>
				<thead><tr><th class="col-md-6">Ora</th><th class="col-md-6">Temperatura</th></tr></thead>
				<tbody>
				{{#schedule}}
					{{#decorateShedule}}{{.}}{{/decorateShedule}}
				{{/schedule}}
				</tbody>
			</table>
		</div>
	</div>
	{{/programedit.giorni}}
</div>
<script>
	{{tabactivate}}
</script>