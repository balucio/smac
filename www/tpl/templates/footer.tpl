	
	</main><!-- main end -->

		<div class="clearfix"></div>
	<div class="container"
		<footer role="contentinfo" style="text-align: center;">
			<small>Copyright &copy; <span>2015-{{ "now"|date('y') }}</span> by Saul Bertuccio</small>
		</footer>
	</div>
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