<?php

class Route {

	public
		$model,
		$view,
		$controller;

	public function __construct($model, $view, $controller) {

		$this->model = $model .'Model';
		$this->view = $view .'View';
		$this->controller = $controller . 'Controller';
	}

	public function __get($type) {

		switch ($type) {

			case 'model': return $this->model;
			case 'view' : return $this->view;
			case 'controller' : return $this->controller;

		}

		throw new InvalidArgumentException("Invalid route $type component", 1);
	}
}


class Router {

	const DEFAULT_ROUTE = 'situazione';

	private $table = [];

	public function __construct() {

		// model, view, controller
		$this->table = [

			// Pagina situazione sistema
			'situazione' => new Route('Situazione', 'Situazione', 'Generic'),
		];
	}

	public function __get($route) {

		return array_key_exists(strtolower($route), $this->table)
			? $this->table[strtolower($route)]
			: null;

	}

}
