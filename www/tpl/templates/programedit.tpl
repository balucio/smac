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
<div id="programma-giornaliero" class="tab-content col-xs-9 col-sm-9 col-md-9">
	{{#programedit.giorni}}
	<div role="tabpanel" class="tab-pane fade {{#active}}in {{active}}{{/active}}" id="{{#decorateShortDay}}{{num}}{{/decorateShortDay}}">
		<p>{{#decorateDay}}{{num}}{{/decorateDay}}</p>
	</div>
	{{/programedit.giorni}}
</div>
<script>
	{{tabactivate}}
</script>