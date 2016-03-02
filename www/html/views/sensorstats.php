<?php

class AndamentoView {

	private $model;
	private $controller;

	private $tplh;

	public function __construct($controller, $model) {
		$this->controller = $controller;
		$this->model = $model;

		$this->tplh = Template::get();

	}

	public function render() {

		return $this->controller->isInitialized()
			? json_encode($this->model->getData(), JSON_NUMERIC_CHECK)
			: json_encode([]);
	}
}