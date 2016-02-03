<ul id="programmazione-settimanale" class="nav nav-tabs" style="margin-bottom: 15px;">
	{{#giorni}}
	<li class="">
		<a href="{{#decorateShortDay}}{{day}}{{/decorateShortDay}}" data-toggle="tab">{{.day}} --</a>
	</li>
	{{/giorni}}
</ul>
<div id="programma-giornaliero" class="tab-content" >
	{{#dettaglio}}
	<div class="tab-pane fade {{activeday}}" id="{{#decorateDay}}{{day}}{{/decorateDay}}">
		<p>{{#decorateDay}}{{day}}{{/decorateDay}}</p>
	</div>
	{{/dettaglio}}
</div>
<script>
	{{tabcollapse}}
</script>
