<?php

class SensorProgramListView extends BaseView {

	public function render() {

		$dcr = new Decorator();

		return json_encode(['sensorlist' => array_values($this->model->get()) ]);

	}
}