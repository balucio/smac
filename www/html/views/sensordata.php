<?php

class SensorDataView {

	private $model;
	private $controller;

	public function __construct($controller, $model) {

		$this->controller = $controller;
		$this->model = $model;
	}

	public function render() {

		$dcr = new Decorator();

		return json_encode(
			[
				'temperature-value' => $dcr->decorateTemperature($this->model->temperatura),
				'humidity-value' => $dcr->decorateUmidity($this->model->umidita),
				'last-update' => $dcr->decorateDateTime($this->model->ultimo_aggiornamento)
			],
			JSON_FORCE_OBJECT | JSON_HEX_QUOT | JSON_HEX_TAG);

	}
}