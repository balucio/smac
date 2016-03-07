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

</head>
<body>

	<header role="banner" class="page-header">
		<h2>SMAC</h2>
		<h5>Sistema Avanzato controllo Clima</h5>
	</header>

	<main role="main">
	{{message|raw}}
	{% include 'footer.tpl' %}