<!DOCTYPE html>

<html lang="{{ language|default('it') }}">
<head>
	<meta charset="utf-8">

	{% include 'favicon.tpl' %}

	<title>SMAC</title>

	<meta name="author" content="Saul Bertuccio">
	<meta name="description" content="SMAC Sistema di Misurazione avanzato condizioni climatiche">

	<!-- Mobile-friendly viewport -->
	<meta name="viewport" content="width=device-width, initial-scale=1.0">

	<!-- Style sheet link -->
	{% for link in css|default(null) %}
		<link rel="stylesheet" href="{{ link }}" media="all">
	{% endfor %}

	<!-- Inline Style -->
	{% for style in internalCss|default(null) %}
		<style>{{ style }}</style>
	{% endfor %}

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
					<p class="navbar-brand"><img alt="Smac" src="/img/logo.png"></p>
				</div>
				<div class="collapse navbar-collapse" id="smac-navbar">
					<ul class="nav navbar-nav">
						<li class="{{sit_selected|default('')}}"><a href="/situazione">Stato sistema</a></li>
						<li class="{{stt_selected|default('')}}"><a href="/statistiche">Statistiche</a></li>
						<li class="dropdown {{imp_selected|default('')}}">
							<a href="#" class="dropdown-toggle" data-toggle="dropdown" role="button"
									aria-haspopup="true" aria-expanded="false">
								Impostazioni <span class="caret"></span>
							</a>
							<ul class="dropdown-menu">
								<li><a href="/impostazioni/generali">Generali</a></li>
								<li><a href="/impostazioni/programmi">Programmi</a></li>
								<li><a href="/impostazioni/sensori">Sensori</a></li>
							</ul>
						</li>
					</ul>
				</div>
			</div>
		</nav>
