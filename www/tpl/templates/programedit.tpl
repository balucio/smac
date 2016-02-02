<ul id="programmazione-settimanale" class="nav nav-tabs" style="margin-bottom: 15px;">
	{{#giorni}}
	<li class="">
		<a href="{{#decorateShordDay}}#{{key}}{{/decorateShordDay}}" data-toggle="tab">{{#decorateDay}}{{key}}{{/decorateDay}}</a>
	</li>
	{{/giorni}}
</ul>
<div id="programma-giornaliero" class="tab-content" >
	{{#giorni}}
	<div class="tab-pane fade {{activeday}}" id="{{#decorateDay}}{{key}}{{/decorateDay}}">
		<p>{{#decorateDay}}{{key}}{{/decorateDay}}</p>
	</div>
	{{/giorni}}
</div>
<script>
	{{tabcollapse}}
</script>
