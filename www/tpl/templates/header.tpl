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

	<!-- Inline Style -->
	{{#internalCss}}
	<style>
	{{ . }}
	</style>
	{{/internalCss}}

</head>
<body>
<!--
	<header role="banner" class="page-header">
		<h2>SMAC</h2>
		<h5>Sistema Avanzato controllo Clima</h5>
	</header>
-->
	<main role="main">
		<nav class="navbar navbar-default navbar-static-top navbar-inverse">
			<div class="container-fluid">
				<div class="navbar-header">
					<button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#smac-navbar" aria-expanded="false">
						<span class="sr-only">Menu</span>
						<span class="icon-bar"></span>
						<span class="icon-bar"></span>
						<span class="icon-bar"></span>
					</button>
					<p class="navbar-brand"><img alt="Smac" src="img/logo.png"></p>
				</div>
				<div class="collapse navbar-collapse" id="smac-navbar">
					<ul class="nav navbar-nav">
						<li class="{{sit_selected}}"><a href="/situazione">Stato sistema</a></li>
						<li class="{{stt_selected}}"><a href="/statistiche">Statistiche</a></li>
						<li class="{{imp_selected}}"><a href="/impostazioni">Impostazioni</a></li>
					</ul>
				</div>
			</div>
		</nav>
