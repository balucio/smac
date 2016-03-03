<?php

class SensorStatsView {

	private $model;
	private $controller;

	public function __construct($controller, $model) {

		$this->controller = $controller;
		$this->model = $model;
	}

	public function render() {

		return json_encode($this->model->getData(), JSON_NUMERIC_CHECK);
	}
}