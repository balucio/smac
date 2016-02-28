<?php

class SensorStatusView {

	private
		$model,
		$controller
	;

	public function __construct($controller, $model) {

		$this->controller = $controller;
		$this->model = $model;

		Assets::get()->addJs('/js/situazione.js');
	}

	public function render() {

		$tpl = Template::get()->loadTemplate('statosensori');
		$dcr = new Decorator();

		return $tpl->render([
			'in_average_sensor' => $this->model->sensorlist(SensorStatusModel::IN_MEDIA_SENSOR),
			'other_sensor' => $this->model->sensorlist(SensorStatusModel::OTHER_SENSOR),
			'have_others' => count($this->model->sensorlist(SensorStatusModel::OTHER_SENSOR)) > 0,
			'decorateTemperature' => [$dcr, 'decorateTemperature'],
			'decorateUmidity' => [$dcr, 'decorateUmidity'],
			'decorateDateTime' => [$dcr, 'decorateDateTime'],
			'sensor' => $this->model->sensordata()
		]);
	}

}