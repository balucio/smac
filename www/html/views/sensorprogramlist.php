<?php

class SensorProgramListView extends BaseView {

	public function render() {

		return json_encode(['sensorlist' => array_values($this->model->get()) ]);

	}
}