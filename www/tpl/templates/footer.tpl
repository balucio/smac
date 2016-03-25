	</main><!-- End primary page content -->
	<div class="clearfix"></div>
	<footer role="contentinfo" style="text-align: center;">
		<small>Copyright &copy; <span>2013-{{ "now"|date('y') }}</span> by Saul Bertuccio</small>
	</footer>

	<!-- Javascrip link placing at end of the page in order to not interrupt rendering -->
	{% for link in js|default(null) %}
		<script src="{{link}}"></script>
	{% endfor %}
	<!-- Javascript direct function wrapped in jquery -->
	{% for directJs in jsReady|default([]) %}
	<script>
		jQuery(function(){
			//dom ready codes
			{{ directJs|raw }}
		});
	</script>
	{% endfor %}
</body>
</html>