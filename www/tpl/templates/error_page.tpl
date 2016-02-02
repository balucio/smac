<!DOCTYPE html>

<html lang="{{ language }}">
<head>
	<meta charset="utf-8">

		<link rel="apple-touch-icon" sizes="57x57" href="/img/fav/apple-icon-57x57.png">
		<link rel="apple-touch-icon" sizes="60x60" href="/img/fav/apple-icon-60x60.png">
		<link rel="apple-touch-icon" sizes="72x72" href="/img/fav/apple-icon-72x72.png">
		<link rel="apple-touch-icon" sizes="76x76" href="/img/fav/apple-icon-76x76.png">
		<link rel="apple-touch-icon" sizes="114x114" href="/img/fav/apple-icon-114x114.png">
		<link rel="apple-touch-icon" sizes="120x120" href="/img/fav/apple-icon-120x120.png">
		<link rel="apple-touch-icon" sizes="144x144" href="/img/fav/apple-icon-144x144.png">
		<link rel="apple-touch-icon" sizes="152x152" href="/img/fav/apple-icon-152x152.png">
		<link rel="apple-touch-icon" sizes="180x180" href="/img/fav/apple-icon-180x180.png">
		<link rel="icon" type="image/png" sizes="192x192"  href="/img/fav/android-icon-192x192.png">
		<link rel="icon" type="image/png" sizes="32x32" href="/img/fav/favicon-32x32.png">
		<link rel="icon" type="image/png" sizes="96x96" href="/img/fav/favicon-96x96.png">
		<link rel="icon" type="image/png" sizes="16x16" href="/img/fav/favicon-16x16.png">
		<link rel="manifest" href="/img/fav/manifest.json">
		<meta name="msapplication-TileColor" content="#ffffff">
		<meta name="msapplication-TileImage" content="/img/fav/ms-icon-144x144.png">
		<meta name="theme-color" content="#ffffff">

	<title>SMAC</title>

	<meta name="author" content="Saul Bertuccio">
	<meta name="description" content="SMAC Sistema di Misurazione avanzato condizioni climatiche">

	<!-- Mobile-friendly viewport -->
	<meta name="viewport" content="width=device-width, initial-scale=1.0">

	<!-- Style sheet link -->
	{{#css}}
	<link rel="stylesheet" href="{{.}}" media="all">
	{{/css}}

</head>
<body>

	<header role="banner" class="page-header">
		<h2>SMAC</h2>
		<h5>Sistema Avanzato controllo Clima</h5>
	</header>

	<main role="main">
	{{&message}}
	</main><!-- End primary page content -->
	<div class="clearfix"></div>
	<footer role="contentinfo">
		<small>Copyright &copy; <time datetime="2013">2013</time> by Saul Bertuccio</small>
	</footer>

	<!-- Javascrip link placing at end of the page in order to not interrupt rendering -->
	{{#js}}
	<script src="{{.}}"></script>
	{{/js}}
</body>
</html>