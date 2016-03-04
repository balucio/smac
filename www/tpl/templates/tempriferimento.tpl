{% for t in temperature %}
	<div class="col-xs-4 col-md-2 text-right" id="t_name_{{t.id}}">
		<h5>T<sub>{{t.id}}</sub></h5>
	</div>
		<div class="col-xs-8 col-md-4">
		<h5>
			{{t.val|Temperature|raw}}
			<span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
		</h5>
	</div>
{% endfor %}