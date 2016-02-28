	</main><!-- End primary page content -->
	<div class="clearfix"></div>
	<footer role="contentinfo">
		<small>Copyright &copy; <span>2013-{{ "now"|date('y') }}</span> by Saul Bertuccio</small>
	</footer>

	<!-- Javascrip link placing at end of the page in order to not interrupt rendering -->
	{% for link in js %}
		<script src="{{link}}"></script>
	{% endfor %}
</body>
</html>